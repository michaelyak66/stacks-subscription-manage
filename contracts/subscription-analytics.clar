;; Subscription Analytics and Loyalty Rewards System
;; Tracks user engagement metrics and provides loyalty rewards for active subscribers

(define-constant ERR-NOT-AUTHORIZED u3001)
(define-constant ERR-USER-NOT-FOUND u3002)
(define-constant ERR-INSUFFICIENT-POINTS u3003)
(define-constant ERR-REWARD-NOT-FOUND u3004)
(define-constant ERR-NO-SUBSCRIPTION u3005)
(define-constant ERR-ALREADY-CLAIMED u3006)
(define-constant ERR-INVALID-STREAK u3007)

;; Loyalty tier thresholds and multipliers
(define-constant BRONZE-THRESHOLD u30)   ;; 30 days
(define-constant SILVER-THRESHOLD u90)   ;; 90 days  
(define-constant GOLD-THRESHOLD u365)    ;; 365 days
(define-constant PLATINUM-THRESHOLD u730) ;; 730 days

(define-constant BRONZE-MULTIPLIER u110)   ;; 1.1x points
(define-constant SILVER-MULTIPLIER u125)   ;; 1.25x points
(define-constant GOLD-MULTIPLIER u150)     ;; 1.5x points
(define-constant PLATINUM-MULTIPLIER u200) ;; 2x points

;; User analytics and engagement tracking
(define-map user-analytics
  { user: principal }
  {
    total-subscriptions: uint,
    total-tokens-spent: uint,
    current-streak-days: uint,
    longest-streak-days: uint,
    loyalty-points: uint,
    loyalty-tier: (string-ascii 12),
    first-subscription-time: uint,
    last-activity-time: uint,
    renewals-count: uint,
    early-renewals-count: uint
  })

;; Global platform analytics
(define-map platform-metrics
  { metric-type: (string-ascii 20) }
  { value: uint, last-updated: uint })

;; Loyalty rewards catalog
(define-map loyalty-rewards
  { reward-id: uint }
  {
    name: (string-ascii 32),
    description: (string-ascii 128),
    points-cost: uint,
    token-reward: uint,
    discount-percent: uint,
    active: bool,
    total-claimed: uint
  })

;; User reward claims tracking
(define-map user-rewards-claimed
  { user: principal, reward-id: uint }
  { claimed-at: uint, tokens-received: uint })

;; Daily activity tracking for streak calculation
(define-map daily-activity
  { user: principal, day: uint }
  { active: bool, subscription-active: bool })

;; Reward counter for generating unique IDs
(define-map reward-counter
  { counter: (string-ascii 7) }
  { value: uint })

;; Initialize platform with default rewards
(define-private (init-platform-rewards)
  (begin
    ;; Reward 1: Token bonus
    (map-set loyalty-rewards { reward-id: u1 }
      { name: "Token Bonus", description: "Receive 50 bonus tokens", 
        points-cost: u100, token-reward: u50, discount-percent: u0, 
        active: true, total-claimed: u0 })
    ;; Reward 2: Renewal discount
    (map-set loyalty-rewards { reward-id: u2 }
      { name: "Renewal Discount", description: "20% off next renewal", 
        points-cost: u150, token-reward: u0, discount-percent: u20, 
        active: true, total-claimed: u0 })
    ;; Reward 3: Premium upgrade
    (map-set loyalty-rewards { reward-id: u3 }
      { name: "Premium Upgrade", description: "Free premium tier for 7 days", 
        points-cost: u300, token-reward: u100, discount-percent: u0, 
        active: true, total-claimed: u0 })
    (map-set reward-counter { counter: "rewards" } { value: u3 })
    (ok true)))

;; Calculate current streak for a user (simplified non-recursive version)
(define-private (calculate-streak (user principal) (current-day uint))
  (match (map-get? user-analytics { user: user })
    existing-data
    (let ((yesterday (- current-day u1)))
      (match (map-get? daily-activity { user: user, day: yesterday })
        yesterday-data
        (if (get subscription-active yesterday-data)
            (+ (get current-streak-days existing-data) u1)
            u1)
        u1))
    u1))

;; Record subscription activity and update analytics
(define-public (record-subscription-activity (user principal) (tokens-spent uint) (is-renewal bool))
  (let ((current-time (unwrap-panic (get-stacks-block-info? time u0)))
        (current-day (/ current-time u86400)))
    (match (map-get? user-analytics { user: user })
      existing-data
      (let ((new-subscriptions (if is-renewal 
                                 (get total-subscriptions existing-data)
                                 (+ (get total-subscriptions existing-data) u1)))
            (new-renewals (if is-renewal 
                           (+ (get renewals-count existing-data) u1)
                           (get renewals-count existing-data)))
            (current-streak (calculate-streak user current-day))
            (longest-streak (if (> current-streak (get longest-streak-days existing-data))
                             current-streak
                             (get longest-streak-days existing-data)))
            (base-points (/ tokens-spent u10))
            (tier-multiplier (get-tier-multiplier longest-streak))
            (earned-points (/ (* base-points tier-multiplier) u100))
            (new-loyalty-points (+ (get loyalty-points existing-data) earned-points))
            (new-tier (determine-loyalty-tier longest-streak)))
        (begin
          (map-set user-analytics { user: user }
            { total-subscriptions: new-subscriptions,
              total-tokens-spent: (+ (get total-tokens-spent existing-data) tokens-spent),
              current-streak-days: current-streak,
              longest-streak-days: longest-streak,
              loyalty-points: new-loyalty-points,
              loyalty-tier: new-tier,
              first-subscription-time: (get first-subscription-time existing-data),
              last-activity-time: current-time,
              renewals-count: new-renewals,
              early-renewals-count: (get early-renewals-count existing-data) })
          (map-set daily-activity { user: user, day: current-day }
            { active: true, subscription-active: true })
          (update-platform-metrics tokens-spent)
          (ok earned-points)))
      ;; First-time user
      (begin
        (map-set user-analytics { user: user }
          { total-subscriptions: u1,
            total-tokens-spent: tokens-spent,
            current-streak-days: u1,
            longest-streak-days: u1,
            loyalty-points: (/ tokens-spent u10),
            loyalty-tier: "Bronze",
            first-subscription-time: current-time,
            last-activity-time: current-time,
            renewals-count: u0,
            early-renewals-count: u0 })
        (map-set daily-activity { user: user, day: current-day }
          { active: true, subscription-active: true })
        (update-platform-metrics tokens-spent)
        (ok (/ tokens-spent u10))))))

;; Determine loyalty tier based on streak
(define-private (determine-loyalty-tier (streak-days uint))
  (if (>= streak-days PLATINUM-THRESHOLD)
      "Platinum"
      (if (>= streak-days GOLD-THRESHOLD)
          "Gold"
          (if (>= streak-days SILVER-THRESHOLD)
              "Silver"
              "Bronze"))))

;; Get tier multiplier for points calculation
(define-private (get-tier-multiplier (streak-days uint))
  (if (>= streak-days PLATINUM-THRESHOLD)
      PLATINUM-MULTIPLIER
      (if (>= streak-days GOLD-THRESHOLD)
          GOLD-MULTIPLIER
          (if (>= streak-days SILVER-THRESHOLD)
              SILVER-MULTIPLIER
              BRONZE-MULTIPLIER))))

;; Update global platform metrics
(define-private (update-platform-metrics (tokens-spent uint))
  (let ((current-time (unwrap-panic (get-stacks-block-info? time u0))))
    (begin
      ;; Update total tokens spent
      (match (map-get? platform-metrics { metric-type: "total-tokens" })
        existing-tokens
        (map-set platform-metrics { metric-type: "total-tokens" }
          { value: (+ (get value existing-tokens) tokens-spent), last-updated: current-time })
        (map-set platform-metrics { metric-type: "total-tokens" }
          { value: tokens-spent, last-updated: current-time }))
      ;; Update total subscriptions
      (match (map-get? platform-metrics { metric-type: "total-subscriptions" })
        existing-subs
        (map-set platform-metrics { metric-type: "total-subscriptions" }
          { value: (+ (get value existing-subs) u1), last-updated: current-time })
        (map-set platform-metrics { metric-type: "total-subscriptions" }
          { value: u1, last-updated: current-time }))
      true)))

;; Claim loyalty reward
(define-public (claim-loyalty-reward (reward-id uint))
  (match (map-get? loyalty-rewards { reward-id: reward-id })
    reward-data
    (if (get active reward-data)
        (match (map-get? user-analytics { user: tx-sender })
          user-data
          (if (>= (get loyalty-points user-data) (get points-cost reward-data))
              (match (map-get? user-rewards-claimed { user: tx-sender, reward-id: reward-id })
                existing-claim
                (err ERR-ALREADY-CLAIMED)
                (let ((current-time (unwrap-panic (get-stacks-block-info? time u0)))
                      (new-points (- (get loyalty-points user-data) (get points-cost reward-data))))
                  (begin
                    ;; Deduct points from user
                    (map-set user-analytics { user: tx-sender }
                      (merge user-data { loyalty-points: new-points }))
                    ;; Record claim
                    (map-set user-rewards-claimed { user: tx-sender, reward-id: reward-id }
                      { claimed-at: current-time, tokens-received: (get token-reward reward-data) })
                    ;; Update reward statistics
                    (map-set loyalty-rewards { reward-id: reward-id }
                      (merge reward-data { total-claimed: (+ (get total-claimed reward-data) u1) }))
                    (ok (get token-reward reward-data)))))
              (err ERR-INSUFFICIENT-POINTS))
          (err ERR-USER-NOT-FOUND))
        (err ERR-REWARD-NOT-FOUND))
    (err ERR-REWARD-NOT-FOUND)))

;; Get user analytics
(define-read-only (get-user-analytics (user principal))
  (ok (map-get? user-analytics { user: user })))

;; Get platform metrics
(define-read-only (get-platform-metrics (metric-type (string-ascii 20)))
  (ok (map-get? platform-metrics { metric-type: metric-type })))

;; Get all available rewards
(define-read-only (get-loyalty-reward (reward-id uint))
  (ok (map-get? loyalty-rewards { reward-id: reward-id })))

;; Get user's claimed rewards
(define-read-only (get-user-reward-claim (user principal) (reward-id uint))
  (ok (map-get? user-rewards-claimed { user: user, reward-id: reward-id })))

;; Check if user has claimed a specific reward
(define-read-only (has-claimed-reward (user principal) (reward-id uint))
  (is-some (map-get? user-rewards-claimed { user: user, reward-id: reward-id })))

;; Get current loyalty tier for user
(define-read-only (get-user-loyalty-tier (user principal))
  (match (map-get? user-analytics { user: user })
    user-data
    (ok (some (get loyalty-tier user-data)))
    (ok none)))

;; Record early renewal bonus
(define-public (record-early-renewal (user principal))
  (match (map-get? user-analytics { user: user })
    existing-data
    (begin
      (map-set user-analytics { user: user }
        (merge existing-data 
          { early-renewals-count: (+ (get early-renewals-count existing-data) u1),
            loyalty-points: (+ (get loyalty-points existing-data) u25) }))
      (ok true))
    (err ERR-USER-NOT-FOUND)))

;; Initialize rewards system (call once during deployment)
(init-platform-rewards)

