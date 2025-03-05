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



;; Add to existing contract
(define-map referrals 
  { referrer: principal, referee: principal } 
  { reward-claimed: bool })

(define-constant REFERRAL-REWARD u100)

(define-public (refer-user (new-user principal))
  (begin
    (map-insert referrals
      { referrer: tx-sender, referee: new-user }
      { reward-claimed: false })
    (ok true)))


(define-map paused-subscriptions 
  { user: principal } 
  { pause-date: uint, remaining-days: uint })

(define-public (pause-subscription)
  (let ((current-time (unwrap-panic (get-block-info? time u0))))
    (match (map-get? subscriptions {user: tx-sender})
      subscription
      (begin
        (map-insert paused-subscriptions
          {user: tx-sender}
          {pause-date: current-time, 
           remaining-days: (- (get end-time subscription) current-time)})
        (ok true))
      (err "No active subscription"))))


(define-public (gift-subscription (recipient principal) (tier-id uint))
  (match (map-get? subscription-tiers {tier-id: tier-id})
    tier-data
    (begin
      (try! (contract-call? .subscription subscribe (get price tier-data)))
      (map-insert subscriptions
        {user: recipient}
        {end-time: (+ block-height (get duration tier-data)), 
         tokens-locked: (get price tier-data)})
      (ok true))
    (err "Invalid tier")))



(define-constant REFUND-PERCENTAGE u70) ;; 70% refund

(define-public (emergency-cancel)
  (match (map-get? subscriptions {user: tx-sender})
    subscription
    (let ((refund-amount (* (get tokens-locked subscription) 
                           (/ REFUND-PERCENTAGE u100))))
      (begin
        (map-delete subscriptions {user: tx-sender})
        (ok refund-amount)))
    (err "No subscription found")))



(define-map vip-status
  { user: principal }
  { status: bool, perks-used: uint })

(define-constant VIP-THRESHOLD u5000)
(define-constant MAX-PERKS-PER-MONTH u3)

(define-public (claim-vip-perk (perk-id uint))
  (let ((current-time (unwrap-panic (get-block-info? time u0))))
    (match (map-get? vip-status {user: tx-sender})
      status
      (if (< (get perks-used status) MAX-PERKS-PER-MONTH)
          (begin
            (map-set vip-status 
              {user: tx-sender}
              {status: true, perks-used: (+ u1 (get perks-used status))})
            (ok true))
          (err "Monthly perk limit reached"))
      (err "Not a VIP member"))))



(define-map market-factors
  { period: uint }
  { demand-multiplier: uint, base-price: uint })

(define-constant MAX-PRICE-CHANGE u20) ;; 20% max change

(define-public (update-dynamic-price (tier-id uint))
  (let ((current-period (/ (unwrap-panic (get-block-info? time u0)) u86400))
        (market-data (unwrap! (map-get? market-factors {period: current-period}) (err "No market data")))
        (tier-info (unwrap! (map-get? subscription-tiers {tier-id: tier-id}) (err "Invalid tier"))))
    (ok (/ (* (get base-price market-data) 
             (get demand-multiplier market-data)) 
          u100))))



(define-map content-access
  { content-id: uint }
  { required-tier: uint, access-count: uint })

(define-constant PREMIUM-CONTENT-TIERS
  {
    basic: u1,
    premium: u2,
    exclusive: u3
  })

(define-read-only (get-user-tier (user principal))
  (match (map-get? subscriptions {user: user})
    subscription
    (let ((tokens-locked (get tokens-locked subscription)))
      (if (>= tokens-locked u5000)
        u3
        (if (>= tokens-locked u2500)
          u2
          u1)))
    u0))

(define-public (access-premium-content (content-id uint))
  (let ((user-tier (get-user-tier tx-sender))
        (content (unwrap! (map-get? content-access {content-id: content-id}) 
                         (err "Content not found"))))
    (if (>= user-tier (get required-tier content))
        (begin
          (map-set content-access
            {content-id: content-id}
            {required-tier: (get required-tier content),
             access-count: (+ u1 (get access-count content))})
          (ok true))
        (err "Insufficient tier level"))))


(define-map loyalty-points 
  { user: principal } 
  { points: uint, last-update: uint })

(define-constant POINTS-PER-MONTH u10)

(define-public (claim-loyalty-rewards)
  (let ((current-time (unwrap-panic (get-block-info? time u0)))
        (user-points (default-to { points: u0, last-update: u0 }
                     (map-get? loyalty-points { user: tx-sender }))))
    (ok (map-set loyalty-points
         { user: tx-sender }
         { points: (+ (get points user-points) POINTS-PER-MONTH),
           last-update: current-time }))))


(define-map group-subscriptions
  { group-id: uint }
  { members: (list 10 principal), discount-rate: uint })

(define-map group-counter
  { counter: (string-utf8 8) }
  { last-id: uint })

(define-constant GROUP-MIN-MEMBERS u3)
(define-constant GROUP-DISCOUNT u15) ;; 15% discount

(define-read-only (get-last-group-id)
  (get last-id (map-get? group-counter {counter: u"groups"})))

(define-public (create-group-subscription (members (list 10 principal)))
  (let ((member-count (len members)))
    (if (>= member-count GROUP-MIN-MEMBERS)
        (ok (map-set group-subscriptions
            { group-id: (+ u1 (default-to u0 (get-last-group-id))) }
            { members: members, discount-rate: GROUP-DISCOUNT }))
        (err "Insufficient members"))))



(define-map gift-counter
  { counter: (string-utf8 8) }
  { last-id: uint })

(define-map gift-messages
  { gift-id: uint }
  { sender: principal, recipient: principal, message: (string-utf8 280) })

(define-read-only (get-last-gift-id)
  (get last-id (map-get? gift-counter {counter: u"gifts"})))

(define-public (send-subscription-gift (recipient principal) (tier-id uint) (message (string-utf8 280)))
  (let ((gift-id (+ u1 (default-to u0 (get-last-gift-id)))))
    (begin
      (try! (gift-subscription recipient tier-id))
      (ok (map-set gift-messages
          { gift-id: gift-id }
          { sender: tx-sender, recipient: recipient, message: message })))))


(define-map season-counter
  { counter: (string-utf8 8) }
  { last-id: uint })

(define-map seasonal-promotions
  { season-id: uint }
  { start-time: uint, end-time: uint, discount: uint })

(define-constant WINTER-PROMO-DISCOUNT u20)

(define-read-only (get-last-season-id)
  (get last-id (map-get? season-counter {counter: u"seasons"})))

(define-public (activate-seasonal-promotion (start-time uint) (duration uint))
  (ok (map-set seasonal-promotions
      { season-id: (+ u1 (default-to u0 (get-last-season-id))) }
      { start-time: start-time,
        end-time: (+ start-time duration),
        discount: WINTER-PROMO-DISCOUNT })))


(define-map creator-revenues
  { creator: principal }
  { total-earnings: uint, last-payout: uint })

(define-constant CREATOR-SHARE-PERCENT u70)

(define-read-only (get-creator-earnings (creator principal))
  (default-to u0 (get total-earnings (map-get? creator-revenues {creator: creator}))))

(define-public (distribute-creator-revenue (amount uint))
  (let ((creator-amount (* amount (/ CREATOR-SHARE-PERCENT u100)))
        (current-earnings (default-to { total-earnings: u0, last-payout: u0 } 
                         (map-get? creator-revenues { creator: tx-sender }))))
    (ok (map-set creator-revenues
        { creator: tx-sender }
        { total-earnings: (+ creator-amount (get total-earnings current-earnings)),
          last-payout: (unwrap-panic (get-block-info? time u0)) }))))



(define-map bundle-counter
  { counter: (string-utf8 8) }
  { last-id: uint })

(define-map subscription-bundles
  { bundle-id: uint }
  { services: (list 5 uint), bundle-price: uint })

(define-constant BUNDLE-DISCOUNT u10)

(define-read-only (get-last-bundle-id)
  (get last-id (map-get? bundle-counter {counter: u"bundles"})))

(define-public (create-bundle (services (list 5 uint)) (base-price uint))
  (let ((discounted-price (- base-price (* base-price (/ BUNDLE-DISCOUNT u100)))))
    (ok (map-set subscription-bundles
        { bundle-id: (+ u1 (default-to u0 (get-last-bundle-id))) }
        { services: services, bundle-price: discounted-price }))))


(define-map referral-tiers
  { user: principal }
  { referral-count: uint, tier-level: uint, rewards: uint })

(define-constant TIER-THRESHOLDS
  {
    bronze: u5,
    silver: u10,
    gold: u20
  })

(define-read-only (calculate-tier-level (count uint))
  (if (>= count (get gold TIER-THRESHOLDS))
      u3
      (if (>= count (get silver TIER-THRESHOLDS))
          u2
          (if (>= count (get bronze TIER-THRESHOLDS))
              u1
              u0))))

(define-read-only (calculate-tier-rewards (count uint))
  (let ((tier (calculate-tier-level count)))
    (* count (+ u100 (* tier u50)))))

(define-public (update-referral-tier)
  (let ((current-refs (default-to { referral-count: u0, tier-level: u0, rewards: u0 }
                      (map-get? referral-tiers { user: tx-sender }))))
    (ok (map-set referral-tiers
        { user: tx-sender }
        { referral-count: (+ u1 (get referral-count current-refs)),
          tier-level: (calculate-tier-level (+ u1 (get referral-count current-refs))),
          rewards: (calculate-tier-rewards (+ u1 (get referral-count current-refs))) }))))
