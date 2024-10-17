(define-map subscriptions 
  { user: principal } 
  { end-time: uint, tokens-locked: uint })

(define-constant TOKEN-LOCK-DURATION 2592000) ;; 30 days in seconds
(define-constant RENEWAL_DISCOUNT 10) ;; 10% bonus for early renewal

;; Ensure the amount is valid before inserting the subscription
(define-public (subscribe (amount uint))
  (if (<= amount u0)
      (err "Amount must be greater than 0")
      (let ((end-time (+ (unwrap-panic (get-block-info? time u0)) 
                         (to-uint TOKEN-LOCK-DURATION))))
        (begin
          (map-insert subscriptions 
            { user: tx-sender } 
            { end-time: end-time, tokens-locked: amount })
          (ok end-time)))))

;; Renew an existing subscription if available
(define-public (renew)
  (match (map-get? subscriptions { user: tx-sender })
    subscription
    (let ((current-end (get end-time subscription))
          (new-end (+ current-end (to-uint TOKEN-LOCK-DURATION))))
      (begin
        (map-set subscriptions 
          { user: tx-sender }
          { end-time: new-end, tokens-locked: (get tokens-locked subscription) })
        (ok new-end)))
    (err "No active subscription")))

;; Retrieve subscription details for a given user
(define-read-only (get-subscription (user principal))
  (ok (map-get? subscriptions { user: user })))

;; Check if a user's subscription is still active
(define-read-only (is-active (user principal))
  (match (map-get? subscriptions { user: user })
    subscription
    (ok (>= (get end-time subscription) block-height))
    (ok false)))
