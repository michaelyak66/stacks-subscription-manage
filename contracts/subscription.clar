;; Manages subscriptions for users, allowing them to subscribe and renew their subscriptions.
;; 
;; The `subscriptions` map stores the subscription details for each user, including the end time of the subscription and the number of tokens locked.
;; 
;; The `subscribe` function allows a user to subscribe by providing an amount of tokens to lock. The subscription will last for 30 days.
;; 
;; The `renew` function allows a user to renew their existing subscription, extending the end time by an additional 30 days..
;; 
;; The `get-subscription` function retrieves the subscription details for a given user.
;; 
;; The `is-active` function checks if a user's subscription is still active.

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

(define-map referrals
  { referrer: principal }
  { total-referrals: uint, rewards-earned: uint })

(define-public (subscribe-with-referral (amount uint) (referrer principal))
  (begin
    (try! (subscribe amount))
    (match (map-get? referrals { referrer: referrer })
      referral-data
      (map-set referrals
        { referrer: referrer }
        { total-referrals: (+ (get total-referrals referral-data) u1),
          rewards-earned: (+ (get rewards-earned referral-data) (/ amount u10)) })
      (map-insert referrals
        { referrer: referrer }
        { total-referrals: u1, rewards-earned: (/ amount u10) }))
    (ok true)))


(define-map paused-subscriptions
  { user: principal }
  { pause-time: uint, remaining-time: uint })

(define-public (pause-subscription)
  (match (map-get? subscriptions { user: tx-sender })
    subscription
    (let ((current-time (unwrap-panic (get-block-info? time u0))))
      (begin
        (map-insert paused-subscriptions
          { user: tx-sender }
          { pause-time: current-time,
            remaining-time: (- (get end-time subscription) current-time) })
        (map-delete subscriptions { user: tx-sender })
        (ok true)))
    (err "No active subscription")))


