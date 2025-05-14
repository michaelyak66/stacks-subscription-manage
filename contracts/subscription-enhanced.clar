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

;; ttt

(define-map family-plans
  { plan-id: uint }
  { owner: principal, members: (list 5 principal), discount: uint })

(define-constant FAMILY-DISCOUNT u25)
(define-constant MAX-FAMILY-MEMBERS u5)

(define-public (create-family-plan (members (list 5 principal)))
  (let ((plan-id (+ u1 (default-to u0 (get-last-group-id)))))
    (begin
      (map-set family-plans
        { plan-id: plan-id }
        { owner: tx-sender, members: members, discount: FAMILY-DISCOUNT })
      (ok plan-id))))

(define-public (add-family-member (plan-id uint) (new-member principal))
  (let ((plan (unwrap! (map-get? family-plans { plan-id: plan-id }) (err "Plan not found"))))
    (if (is-eq (get owner plan) tx-sender)
        (let ((current-members (get members plan))
              (member-count (len (get members plan))))
          (if (< member-count MAX-FAMILY-MEMBERS)
              (ok (map-set family-plans
                  { plan-id: plan-id }
                  { owner: tx-sender, 
                    members: (unwrap! (as-max-len? (concat current-members (list new-member)) u5) (err "List too long")), 
                    discount: FAMILY-DISCOUNT }))
              (err "Maximum family members reached")))
        (err "Not the plan owner"))))




(define-map subscription-pauses
  { user: principal }
  { paused-at: uint, remaining-time: uint, is-paused: bool })

(define-constant MAX-PAUSE-DURATION u2592000) ;; 30 days in seconds

(define-public (pause-subscription-v2)
  (let ((current-time (unwrap-panic (get-block-info? time u0)))
        (subscription (unwrap! (map-get? subscriptions { user: tx-sender }) (err "No active subscription"))))
    (begin
      (map-set subscription-pauses
        { user: tx-sender }
        { paused-at: current-time, 
          remaining-time: (- (get end-time subscription) current-time),
          is-paused: true })
      (map-delete subscriptions { user: tx-sender })
      (ok true))))

(define-public (resume-subscription)
  (let ((current-time (unwrap-panic (get-block-info? time u0)))
        (pause-data (unwrap! (map-get? subscription-pauses { user: tx-sender }) (err "No paused subscription"))))
    (if (get is-paused pause-data)
        (begin
          (map-set subscriptions
            { user: tx-sender }
            { end-time: (+ current-time (get remaining-time pause-data)), 
              tokens-locked: u0 })
          (map-set subscription-pauses
            { user: tx-sender }
            { paused-at: u0, remaining-time: u0, is-paused: false })
          (ok true))
        (err "Subscription not paused"))))



(define-map auto-renewal-settings
  { user: principal }
  { enabled: bool, last-updated: uint })

(define-public (set-auto-renewal (enabled bool))
  (let ((current-time (unwrap-panic (get-block-info? time u0))))
    (begin
      (map-set auto-renewal-settings
        { user: tx-sender }
        { enabled: enabled, last-updated: current-time })
      (ok enabled))))

(define-read-only (get-auto-renewal-status (user principal))
  (default-to { enabled: true, last-updated: u0 }
              (map-get? auto-renewal-settings { user: user })))

(define-public (process-auto-renewals)
  (let ((current-time (unwrap-panic (get-block-info? time u0)))
        (subscription (unwrap! (map-get? subscriptions { user: tx-sender }) (err "No subscription")))
        (renewal-setting (get-auto-renewal-status tx-sender)))
    (if (and (get enabled renewal-setting)
             (< (get end-time subscription) current-time))
        (as-contract (contract-call? .subscription renew))
        (err "Auto-renewal not needed or disabled"))))



(define-map rewards-program
  { user: principal }
  { points: uint, streak-months: uint, last-reward: uint })

(define-constant POINTS-PER-STREAK u50)
(define-constant POINTS-REDEMPTION-RATE u100) ;; 100 points = 1 STX

(define-public (calculate-streak-rewards)
  (let ((current-time (unwrap-panic (get-block-info? time u0)))
        (rewards (default-to { points: u0, streak-months: u0, last-reward: u0 }
                 (map-get? rewards-program { user: tx-sender })))
        (subscription (unwrap! (map-get? subscriptions { user: tx-sender }) (err "No subscription"))))
    (if (> (get end-time subscription) current-time)
        (ok (map-set rewards-program
            { user: tx-sender }
            { points: (+ (get points rewards) POINTS-PER-STREAK),
              streak-months: (+ u1 (get streak-months rewards)),
              last-reward: current-time }))
        (err "Subscription not active"))))

(define-public (redeem-reward-points (points-to-redeem uint))
  (let ((rewards (unwrap! (map-get? rewards-program { user: tx-sender }) (err "No rewards"))))
    (if (>= (get points rewards) points-to-redeem)
        (ok (map-set rewards-program
            { user: tx-sender }
            { points: (- (get points rewards) points-to-redeem),
              streak-months: (get streak-months rewards),
              last-reward: (get last-reward rewards) }))
        (err "Insufficient points"))))


(define-map volume-discounts
  { tier: uint }
  { min-quantity: uint, discount-percent: uint })

(define-public (initialize-volume-discounts)
  (begin
    (map-set volume-discounts { tier: u1 } { min-quantity: u5, discount-percent: u5 })
    (map-set volume-discounts { tier: u2 } { min-quantity: u10, discount-percent: u10 })
    (map-set volume-discounts { tier: u3 } { min-quantity: u20, discount-percent: u15 })
    (ok true)))

(define-read-only (calculate-volume-discount (quantity uint))
  (let ((tier-1 (default-to { min-quantity: u5, discount-percent: u5 } 
                (map-get? volume-discounts { tier: u1 })))
        (tier-2 (default-to { min-quantity: u10, discount-percent: u10 } 
                (map-get? volume-discounts { tier: u2 })))
        (tier-3 (default-to { min-quantity: u20, discount-percent: u15 } 
                (map-get? volume-discounts { tier: u3 }))))
    (if (>= quantity (get min-quantity tier-3))
        (get discount-percent tier-3)
        (if (>= quantity (get min-quantity tier-2))
            (get discount-percent tier-2)
            (if (>= quantity (get min-quantity tier-1))
                (get discount-percent tier-1)
                u0)))))

(define-public (bulk-purchase (tier-id uint) (quantity uint))
  (let ((tier-data (unwrap! (map-get? subscription-tiers { tier-id: tier-id }) (err "Invalid tier")))
        (discount-percent (calculate-volume-discount quantity))
        (base-price (* (get price tier-data) quantity))
        (discount-amount (/ (* base-price discount-percent) u100))
        (final-price (- base-price discount-amount)))
    (begin
      (try! (contract-call? .subscription subscribe final-price))
      (ok final-price))))


  

  (define-map scheduled-gifts
  { gift-id: uint }
  { sender: principal, recipient: principal, tier-id: uint, delivery-time: uint, message: (string-utf8 280), delivered: bool })

(define-map gift-id-counter
  { counter: (string-utf8 5) }
  { value: uint })

(define-read-only (get-next-gift-id)
  (+ u1 (default-to u0 (get value (map-get? gift-id-counter { counter: u"gifts" })))))

(define-public (schedule-gift (recipient principal) (tier-id uint) (delivery-time uint) (message (string-utf8 280)))
  (let ((gift-id (get-next-gift-id)))
    (begin
      (map-set scheduled-gifts
        { gift-id: gift-id }
        { sender: tx-sender, 
          recipient: recipient, 
          tier-id: tier-id, 
          delivery-time: delivery-time, 
          message: message, 
          delivered: false })
      (map-set gift-id-counter { counter: u"gifts" } { value: gift-id })
      (ok gift-id))))

(define-public (deliver-gift (gift-id uint))
  (let ((gift (unwrap! (map-get? scheduled-gifts { gift-id: gift-id }) (err "Gift not found")))
        (current-time (unwrap-panic (get-block-info? time u0))))
    (if (and (not (get delivered gift)) 
             (>= current-time (get delivery-time gift)))
        (begin
          (try! (gift-subscription (get recipient gift) (get tier-id gift)))
          (map-set scheduled-gifts
            { gift-id: gift-id }
            { sender: (get sender gift), 
              recipient: (get recipient gift), 
              tier-id: (get tier-id gift), 
              delivery-time: (get delivery-time gift), 
              message: (get message gift), 
              delivered: true })
          (ok true))
        (err "Gift not ready for delivery or already delivered"))))





(define-map subscription-milestones
  { milestone-id: uint }
  { months-required: uint, reward-points: uint, description: (string-utf8 100) })

(define-map user-milestones
  { user: principal, milestone-id: uint }
  { achieved: bool, achieved-at: uint })

(define-public (initialize-milestones)
  (begin
    (map-set subscription-milestones 
      { milestone-id: u1 } 
      { months-required: u3, reward-points: u100, description: u"3 Month Subscriber" })
    (map-set subscription-milestones 
      { milestone-id: u2 } 
      { months-required: u6, reward-points: u250, description: u"6 Month Subscriber" })
    (map-set subscription-milestones 
      { milestone-id: u3 } 
      { months-required: u12, reward-points: u500, description: u"1 Year Subscriber" })
    (ok true)))

(define-public (check-milestone-achievement (milestone-id uint))
  (let ((milestone (unwrap! (map-get? subscription-milestones { milestone-id: milestone-id }) 
                           (err "Milestone not found")))
        (rewards (default-to { points: u0, streak-months: u0, last-reward: u0 }
                 (map-get? rewards-program { user: tx-sender })))
        (current-time (unwrap-panic (get-block-info? time u0))))
    (if (>= (get streak-months rewards) (get months-required milestone))
        (begin
          (map-set user-milestones
            { user: tx-sender, milestone-id: milestone-id }
            { achieved: true, achieved-at: current-time })
          (map-set rewards-program
            { user: tx-sender }
            { points: (+ (get points rewards) (get reward-points milestone)),
              streak-months: (get streak-months rewards),
              last-reward: current-time })
          (ok true))
        (err "Milestone requirements not met"))))

      
  

(define-map user-tier-history
  { user: principal }
  { current-tier: uint, previous-tier: uint, last-changed: uint })

(define-constant TIER-CHANGE-COOLDOWN u604800) ;; 7 days in seconds

(define-read-only (get-user-current-tier (user principal))
  (default-to u1 (get current-tier (map-get? user-tier-history { user: user }))))

(define-read-only (calculate-remaining-value (user principal))
  (match (map-get? subscriptions { user: user })
    subscription
    (let ((current-time (unwrap-panic (get-block-info? time u0)))
          (end-time (get end-time subscription))
          (tokens-locked (get tokens-locked subscription)))
      (if (> end-time current-time)
          (let ((total-duration (- end-time (- end-time (get tokens-locked subscription))))
                (remaining-duration (- end-time current-time)))
            (/ (* tokens-locked remaining-duration) total-duration))
          u0))
    u0))

(define-public (change-subscription-tier (new-tier-id uint))
  (let ((current-time (unwrap-panic (get-block-info? time u0)))
        (user-history (default-to { current-tier: u1, previous-tier: u0, last-changed: u0 } 
                      (map-get? user-tier-history { user: tx-sender })))
        (new-tier (unwrap! (map-get? subscription-tiers { tier-id: new-tier-id }) 
                          (err "Invalid tier")))
        (remaining-value (calculate-remaining-value tx-sender)))
    
    (asserts! (> (- current-time (get last-changed user-history)) TIER-CHANGE-COOLDOWN) 
              (err "Tier change cooldown period not elapsed"))
    
    (asserts! (not (is-eq (get current-tier user-history) new-tier-id)) 
              (err "Already subscribed to this tier"))
    
    (let ((price-difference (- (get price new-tier) remaining-value)))
      (begin
        ;; If upgrading (price difference is positive), charge the difference
        ;; If downgrading (price difference is negative), extend subscription duration
        (try! (if (> price-difference u0)
            (contract-call? .subscription subscribe price-difference)
            (ok u0)))
        
        ;; Update subscription record
        (map-set subscriptions
          { user: tx-sender }
          { end-time: (+ current-time (get duration new-tier)), 
            tokens-locked: (get price new-tier) })
        
        ;; Update tier history
        (map-set user-tier-history
          { user: tx-sender }
          { current-tier: new-tier-id, 
            previous-tier: (get current-tier user-history), 
            last-changed: current-time })
        
        (ok new-tier-id)))))



(define-map subscription-analytics
  { period: uint }  ;; Period is a timestamp for the day (truncated to days)
  { 
    active-subscriptions: uint,
    new-subscriptions: uint,
    renewals: uint,
    cancellations: uint,
    upgrades: uint,
    downgrades: uint,
    total-revenue: uint
  })

(define-map user-subscription-events
  { user: principal }
  { 
    first-subscription: uint,
    last-renewal: uint,
    subscription-count: uint,
    tier-changes: uint
  })

(define-read-only (get-current-period)
  (let ((current-time (unwrap-panic (get-block-info? time u0))))
    ;; Truncate to day (86400 seconds in a day)
    (/ current-time u86400)))

(define-read-only (get-period-analytics (period uint))
  (default-to 
    { 
      active-subscriptions: u0,
      new-subscriptions: u0,
      renewals: u0,
      cancellations: u0,
      upgrades: u0,
      downgrades: u0,
      total-revenue: u0
    }
    (map-get? subscription-analytics { period: period })))

(define-public (track-subscription-event (event-type (string-ascii 20)) (amount uint))
  (let ((current-period (get-current-period))
         (current-analytics (get-period-analytics current-period))
         (user-events (default-to 
                        { 
                          first-subscription: (unwrap-panic (get-block-info? time u0)),
                          last-renewal: u0,
                          subscription-count: u0,
                          tier-changes: u0
                        }
                        (map-get? user-subscription-events { user: tx-sender }))))
    
    (begin
      ;; Update the appropriate metric based on event type
      (map-set subscription-analytics
        { period: current-period }
        (if (is-eq event-type "new")
          {
            active-subscriptions: (+ u1 (get active-subscriptions current-analytics)),
            new-subscriptions: (+ u1 (get new-subscriptions current-analytics)),
            renewals: (get renewals current-analytics),
            cancellations: (get cancellations current-analytics),
            upgrades: (get upgrades current-analytics),
            downgrades: (get downgrades current-analytics),
            total-revenue: (+ amount (get total-revenue current-analytics))
          }
          (if (is-eq event-type "renewal")
          {
            active-subscriptions: (get active-subscriptions current-analytics),
            new-subscriptions: (get new-subscriptions current-analytics),
            renewals: (+ u1 (get renewals current-analytics)),
            cancellations: (get cancellations current-analytics),
            upgrades: (get upgrades current-analytics),
            downgrades: (get downgrades current-analytics),
            total-revenue: (+ amount (get total-revenue current-analytics))
          }
          (if (is-eq event-type "cancel")
          {
            active-subscriptions: (- (get active-subscriptions current-analytics) u1),
            new-subscriptions: (get new-subscriptions current-analytics),
            renewals: (get renewals current-analytics),
            cancellations: (+ u1 (get cancellations current-analytics)),
            upgrades: (get upgrades current-analytics),
            downgrades: (get downgrades current-analytics),
            total-revenue: (get total-revenue current-analytics)
          }
          (if (is-eq event-type "upgrade")
          {
            active-subscriptions: (get active-subscriptions current-analytics),
            new-subscriptions: (get new-subscriptions current-analytics),
            renewals: (get renewals current-analytics),
            cancellations: (get cancellations current-analytics),
            upgrades: (+ u1 (get upgrades current-analytics)),
            downgrades: (get downgrades current-analytics),
            total-revenue: (+ amount (get total-revenue current-analytics))
          }
          (if (is-eq event-type "downgrade")
          {
            active-subscriptions: (get active-subscriptions current-analytics),
            new-subscriptions: (get new-subscriptions current-analytics),
            renewals: (get renewals current-analytics),
            cancellations: (get cancellations current-analytics),
            upgrades: (get upgrades current-analytics),
            downgrades: (+ u1 (get downgrades current-analytics)),
            total-revenue: (get total-revenue current-analytics)
          }
          current-analytics))))))
      
      ;; Update user events
      (map-set user-subscription-events
        { user: tx-sender }
        (if (is-eq event-type "new")
          {
            first-subscription: (if (is-eq (get subscription-count user-events) u0)
                                   (unwrap-panic (get-block-info? time u0))
                                   (get first-subscription user-events)),
            last-renewal: (get last-renewal user-events),
            subscription-count: (+ u1 (get subscription-count user-events)),
            tier-changes: (get tier-changes user-events)
          }
          (if (is-eq event-type "renewal")
          {
            first-subscription: (get first-subscription user-events),
            last-renewal: (unwrap-panic (get-block-info? time u0)),
            subscription-count: (get subscription-count user-events),
            tier-changes: (get tier-changes user-events)
          }
          (if (is-eq event-type "upgrade")
          {
            first-subscription: (get first-subscription user-events),
            last-renewal: (get last-renewal user-events),
            subscription-count: (get subscription-count user-events),
            tier-changes: (+ u1 (get tier-changes user-events))
          }
          (if (is-eq event-type "downgrade")
          {
            first-subscription: (get first-subscription user-events),
            last-renewal: (get last-renewal user-events),
            subscription-count: (get subscription-count user-events),
            tier-changes: (+ u1 (get tier-changes user-events))
          }
          user-events)))))
      
      (ok true))))(define-read-only (get-user-subscription-history (user principal))  (default-to 
    { 
      first-subscription: u0,
      last-renewal: u0,
      subscription-count: u0,
      tier-changes: u0
    }
    (map-get? user-subscription-events { user: user })))

(define-read-only (get-analytics-for-range (start-period uint) (end-period uint))
  (let ((periods (- end-period start-period)))
    (if (> periods u30)
        (err "Range too large")
        (ok {
          start-period: start-period,
          end-period: end-period,
          periods: periods
        }))))