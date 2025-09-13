;; Subscription Insurance Contract
;; Provides insurance coverage for subscription interruptions and service failures
;; Integrates with existing subscription system to protect user investments

(define-constant ERR-NOT-AUTHORIZED u4001)
(define-constant ERR-INVALID-PREMIUM u4002)
(define-constant ERR-NO-ACTIVE-SUBSCRIPTION u4003)
(define-constant ERR-POLICY-NOT-FOUND u4004)
(define-constant ERR-CLAIM-ALREADY-FILED u4005)
(define-constant ERR-CLAIM-NOT-FOUND u4006)
(define-constant ERR-CLAIM-EXPIRED u4007)
(define-constant ERR-INSUFFICIENT-FUNDS u4008)
(define-constant ERR-INVALID-CLAIM-AMOUNT u4009)

;; Insurance policy configuration
(define-constant PREMIUM-RATE u5) ;; 5% of subscription value
(define-constant MAX-COVERAGE-PERCENT u80) ;; Max 80% coverage
(define-constant CLAIM-WINDOW u604800) ;; 7 days to file claim after incident
(define-constant MIN-INSURANCE-AMOUNT u100)

;; Insurance policies mapping
(define-map insurance-policies
  { user: principal }
  {
    policy-id: uint,
    subscription-value: uint,
    premium-paid: uint,
    coverage-amount: uint,
    start-time: uint,
    end-time: uint,
    active: bool,
    claims-filed: uint
  })

;; Insurance claims mapping
(define-map insurance-claims
  { claim-id: uint }
  {
    user: principal,
    policy-id: uint,
    claim-amount: uint,
    incident-time: uint,
    filed-time: uint,
    claim-reason: (string-ascii 128),
    status: (string-ascii 20),
    payout-amount: uint,
    processed-time: uint
  })

;; Counters for generating unique IDs
(define-map policy-counter
  { counter: (string-ascii 8) }
  { value: uint })

(define-map claim-counter
  { counter: (string-ascii 6) }
  { value: uint })

;; Insurance fund balance
(define-data-var insurance-fund uint u0)

;; Get next policy ID
(define-read-only (get-next-policy-id)
  (+ u1 (default-to u0 (get value (map-get? policy-counter { counter: "policies" })))))

;; Get next claim ID
(define-read-only (get-next-claim-id)
  (+ u1 (default-to u0 (get value (map-get? claim-counter { counter: "claims" })))))

;; Get current time
(define-read-only (get-current-time)
  (unwrap-panic (get-stacks-block-info? time u0)))

;; Calculate insurance premium based on subscription value and duration
(define-read-only (calculate-premium (subscription-value uint) (duration-days uint))
  (let ((base-premium (/ (* subscription-value PREMIUM-RATE) u100))
        (duration-multiplier (if (> duration-days u90) u150 u100)))
    (/ (* base-premium duration-multiplier) u100)))

;; Get subscription details from enhanced contract
(define-public (get-subscription-info (user principal))
  (contract-call? .subscription-enhanced get-subscription-info user))

;; Purchase insurance policy for active subscription
(define-public (purchase-insurance)
  (let ((subscription-info (unwrap! (get-subscription-info tx-sender) (err ERR-NO-ACTIVE-SUBSCRIPTION)))
        (current-time (get-current-time))
        (policy-id (get-next-policy-id))
        (subscription-value (get tokens-locked subscription-info))
        (end-time (get end-time subscription-info))
        (duration-days (/ (- end-time current-time) u86400))
        (premium (calculate-premium subscription-value duration-days))
        (coverage-amount (/ (* subscription-value MAX-COVERAGE-PERCENT) u100)))
    
    (asserts! (>= subscription-value MIN-INSURANCE-AMOUNT) (err ERR-INVALID-PREMIUM))
    (asserts! (> end-time current-time) (err ERR-NO-ACTIVE-SUBSCRIPTION))
    
    ;; Transfer premium to contract
    (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
    
    ;; Update insurance fund
    (var-set insurance-fund (+ (var-get insurance-fund) premium))
    
    ;; Create insurance policy
    (map-set insurance-policies
      { user: tx-sender }
      {
        policy-id: policy-id,
        subscription-value: subscription-value,
        premium-paid: premium,
        coverage-amount: coverage-amount,
        start-time: current-time,
        end-time: end-time,
        active: true,
        claims-filed: u0
      })
    
    ;; Update policy counter
    (map-set policy-counter { counter: "policies" } { value: policy-id })
    
    (ok { policy-id: policy-id, premium: premium, coverage: coverage-amount })))

;; File insurance claim for subscription interruption
(define-public (file-claim (incident-time uint) (claim-amount uint) (reason (string-ascii 128)))
  (let ((policy (unwrap! (map-get? insurance-policies { user: tx-sender }) (err ERR-POLICY-NOT-FOUND)))
        (current-time (get-current-time))
        (claim-id (get-next-claim-id)))
    
    (asserts! (get active policy) (err ERR-POLICY-NOT-FOUND))
    (asserts! (>= current-time incident-time) (err ERR-CLAIM-EXPIRED))
    (asserts! (<= (- current-time incident-time) CLAIM-WINDOW) (err ERR-CLAIM-EXPIRED))
    (asserts! (> claim-amount u0) (err ERR-INVALID-CLAIM-AMOUNT))
    (asserts! (<= claim-amount (get coverage-amount policy)) (err ERR-INVALID-CLAIM-AMOUNT))
    
    ;; Create insurance claim
    (map-set insurance-claims
      { claim-id: claim-id }
      {
        user: tx-sender,
        policy-id: (get policy-id policy),
        claim-amount: claim-amount,
        incident-time: incident-time,
        filed-time: current-time,
        claim-reason: reason,
        status: "pending",
        payout-amount: u0,
        processed-time: u0
      })
    
    ;; Update policy claims count
    (map-set insurance-policies
      { user: tx-sender }
      (merge policy { claims-filed: (+ (get claims-filed policy) u1) }))
    
    ;; Update claim counter
    (map-set claim-counter { counter: "claims" } { value: claim-id })
    
    (ok claim-id)))

;; Process insurance claim (simplified auto-approval for valid claims)
(define-public (process-claim (claim-id uint))
  (let ((claim (unwrap! (map-get? insurance-claims { claim-id: claim-id }) (err ERR-CLAIM-NOT-FOUND)))
        (policy (unwrap! (map-get? insurance-policies { user: (get user claim) }) (err ERR-POLICY-NOT-FOUND)))
        (current-time (get-current-time))
        (payout-amount (get claim-amount claim)))
    
    (asserts! (is-eq (get status claim) "pending") (err ERR-CLAIM-NOT-FOUND))
    (asserts! (>= (var-get insurance-fund) payout-amount) (err ERR-INSUFFICIENT-FUNDS))
    
    ;; Process payout
    (try! (as-contract (stx-transfer? payout-amount tx-sender (get user claim))))
    
    ;; Update insurance fund
    (var-set insurance-fund (- (var-get insurance-fund) payout-amount))
    
    ;; Update claim status
    (map-set insurance-claims
      { claim-id: claim-id }
      (merge claim {
        status: "approved",
        payout-amount: payout-amount,
        processed-time: current-time
      }))
    
    (ok payout-amount)))

;; Get insurance policy details
(define-read-only (get-policy-details (user principal))
  (ok (map-get? insurance-policies { user: user })))

;; Get claim details
(define-read-only (get-claim-details (claim-id uint))
  (ok (map-get? insurance-claims { claim-id: claim-id })))

;; Check if user has active insurance
(define-read-only (has-active-insurance (user principal))
  (match (map-get? insurance-policies { user: user })
    policy
    (and (get active policy) (> (get end-time policy) (get-current-time)))
    false))

;; Get insurance fund balance
(define-read-only (get-insurance-fund-balance)
  (ok (var-get insurance-fund)))

;; Cancel insurance policy (partial refund if no claims)
(define-public (cancel-insurance)
  (let ((policy (unwrap! (map-get? insurance-policies { user: tx-sender }) (err ERR-POLICY-NOT-FOUND)))
        (current-time (get-current-time)))
    
    (asserts! (get active policy) (err ERR-POLICY-NOT-FOUND))
    (asserts! (is-eq (get claims-filed policy) u0) (err ERR-CLAIM-ALREADY-FILED))
    
    ;; Calculate refund (50% if canceling early)
    (let ((refund-amount (/ (get premium-paid policy) u2)))
      
      ;; Transfer refund
      (try! (as-contract (stx-transfer? refund-amount tx-sender tx-sender)))
      
      ;; Update insurance fund
      (var-set insurance-fund (- (var-get insurance-fund) refund-amount))
      
      ;; Deactivate policy
      (map-set insurance-policies
        { user: tx-sender }
        (merge policy { active: false }))
      
      (ok refund-amount))))
