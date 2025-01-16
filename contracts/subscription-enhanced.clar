;; title: subscription-enhanced

;; Import the base contract
(as-contract (contract-call? .subscription subscribe u19))
(as-contract (contract-call? .subscription renew))
(define-constant TOKEN-LOCK-DURATION 2592000) ;; 30 days in seconds
(define-map subscriptions { user: principal } { end-time: uint, tokens-locked:uint })
(define-map subscription-tiers { tier-id: uint } { price: uint, duration: uint, benefits: (string-utf8 64) }) ;; Add tier definitions
(define-constant GRACE-PERIOD u259200) ;; 3 days in seconds



;; Modified subscribe function using contract-call
(define-public (subscribe-with-tier (tier-id uint))
  (match (map-get? subscription-tiers { tier-id: tier-id })
    tier-data
    (contract-call? .subscription subscribe (get price tier-data))
    (err "Invalid tier")))



(define-read-only (is-active (user principal))
  (match (map-get? subscriptions { user: user })
    subscription
    (ok (>= (+ (get end-time subscription) GRACE-PERIOD) block-height))
    (ok false)))


(define-public (early-renew)
  (match (map-get? subscriptions { user: tx-sender })
    subscription
    (let ((current-time (unwrap-panic (get-block-info? time u0)))
          (bonus-threshold (- (get end-time subscription) u604800))) ;; 7 days before expiry
      (if (< current-time bonus-threshold)
          (let ((bonus-amount (/ (get tokens-locked subscription) u10)))
            (begin
              (try! (as-contract (contract-call? .subscription renew)))
              (ok bonus-amount)))
          (as-contract (contract-call? .subscription renew))))
    (err "No active subscription")))



(define-public (subscribe-bulk (amount uint) (months uint))
  (let ((discount-rate (/ u1 u20)) ;; 5% discount
        (total-amount (* amount months))
        (discounted-amount (- total-amount (* total-amount discount-rate)))
        (end-time (+ (unwrap-panic (get-block-info? time u0))
                    (* (to-uint TOKEN-LOCK-DURATION) months))))
    (begin
      (map-insert subscriptions
        { user: tx-sender }
        { end-time: end-time, tokens-locked: discounted-amount })
      (ok end-time))))
