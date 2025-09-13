(define-constant ERR-NOT-AUTHORIZED u2001)
(define-constant ERR-RENTAL-NOT-FOUND u2002)
(define-constant ERR-INSUFFICIENT-PAYMENT u2003)
(define-constant ERR-NO-ACTIVE-SUBSCRIPTION u2004)
(define-constant ERR-INVALID-RENTAL-PERIOD u2005)
(define-constant ERR-CANNOT-RENT-OWN-LISTING u2006)
(define-constant ERR-RENTAL-EXPIRED u2007)
(define-constant ERR-ALREADY-RENTED u2008)
(define-constant ERR-RENTAL-TOO-LONG u2009)

(define-constant RENTAL-FEE-PERCENT u3)
(define-constant MIN-RENTAL-PERIOD u3600)
(define-constant MAX-RENTAL-PERIOD u604800)

(define-map rental-listings
  { rental-id: uint }
  { 
    owner: principal,
    renter: (optional principal),
    hourly-rate: uint,
    max-rental-period: uint,
    subscription-end-time: uint,
    created-at: uint,
    active: bool,
    currently-rented: bool
  })

(define-map active-rentals
  { rental-id: uint }
  {
    renter: principal,
    rental-start: uint,
    rental-end: uint,
    total-paid: uint
  })

(define-map rental-counter
  { counter: (string-ascii 7) }
  { value: uint })

(define-map user-rental-history
  { user: principal }
  { rental-count: uint, total-earned: uint, total-spent: uint })

(define-read-only (get-next-rental-id)
  (+ u1 (default-to u0 (get value (map-get? rental-counter { counter: "rentals" })))))

(define-read-only (get-current-time)
  (unwrap-panic (get-stacks-block-info? time u0)))

(define-public (get-subscription-details (user principal))
  (contract-call? .subscription-enhanced get-subscription-info user))

(define-public (create-rental-listing (hourly-rate uint) (max-rental-hours uint))
  (let ((current-time (get-current-time))
        (rental-id (get-next-rental-id))
        (max-rental-seconds (* max-rental-hours u3600))
        (subscription-info (unwrap! (get-subscription-details tx-sender) (err ERR-NO-ACTIVE-SUBSCRIPTION))))
    
    (asserts! (> hourly-rate u0) (err ERR-INVALID-RENTAL-PERIOD))
    (asserts! (>= max-rental-seconds MIN-RENTAL-PERIOD) (err ERR-INVALID-RENTAL-PERIOD))
    (asserts! (<= max-rental-seconds MAX-RENTAL-PERIOD) (err ERR-RENTAL-TOO-LONG))
    (asserts! (> (get end-time subscription-info) (+ current-time max-rental-seconds)) (err ERR-RENTAL-EXPIRED))
    
    (map-set rental-listings
      { rental-id: rental-id }
      {
        owner: tx-sender,
        renter: none,
        hourly-rate: hourly-rate,
        max-rental-period: max-rental-seconds,
        subscription-end-time: (get end-time subscription-info),
        created-at: current-time,
        active: true,
        currently-rented: false
      })
    
    (map-set rental-counter { counter: "rentals" } { value: rental-id })
    
    (ok rental-id)))

(define-public (rent-subscription (rental-id uint) (rental-hours uint))
  (let ((listing (unwrap! (map-get? rental-listings { rental-id: rental-id }) (err ERR-RENTAL-NOT-FOUND)))
        (current-time (get-current-time))
        (rental-seconds (* rental-hours u3600))
        (rental-end-time (+ current-time rental-seconds))
        (total-cost (* (get hourly-rate listing) rental-hours)))
    
    (asserts! (get active listing) (err ERR-RENTAL-NOT-FOUND))
    (asserts! (not (get currently-rented listing)) (err ERR-ALREADY-RENTED))
    (asserts! (not (is-eq tx-sender (get owner listing))) (err ERR-CANNOT-RENT-OWN-LISTING))
    (asserts! (>= rental-seconds MIN-RENTAL-PERIOD) (err ERR-INVALID-RENTAL-PERIOD))
    (asserts! (<= rental-seconds (get max-rental-period listing)) (err ERR-RENTAL-TOO-LONG))
    (asserts! (< rental-end-time (get subscription-end-time listing)) (err ERR-RENTAL-EXPIRED))
    
    (let ((rental-fee (/ (* total-cost RENTAL-FEE-PERCENT) u100))
          (owner-amount (- total-cost rental-fee)))
      
      (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
      (try! (as-contract (stx-transfer? owner-amount tx-sender (get owner listing))))
      
      (map-set active-rentals
        { rental-id: rental-id }
        {
          renter: tx-sender,
          rental-start: current-time,
          rental-end: rental-end-time,
          total-paid: total-cost
        })
      
      (map-set rental-listings
        { rental-id: rental-id }
        {
          owner: (get owner listing),
          renter: (some tx-sender),
          hourly-rate: (get hourly-rate listing),
          max-rental-period: (get max-rental-period listing),
          subscription-end-time: (get subscription-end-time listing),
          created-at: (get created-at listing),
          active: true,
          currently-rented: true
        })
      
      (let ((renter-history (default-to { rental-count: u0, total-earned: u0, total-spent: u0 }
                            (map-get? user-rental-history { user: tx-sender })))
            (owner-history (default-to { rental-count: u0, total-earned: u0, total-spent: u0 }
                           (map-get? user-rental-history { user: (get owner listing) }))))
        
        (map-set user-rental-history
          { user: tx-sender }
          {
            rental-count: (+ u1 (get rental-count renter-history)),
            total-earned: (get total-earned renter-history),
            total-spent: (+ total-cost (get total-spent renter-history))
          })
        
        (map-set user-rental-history
          { user: (get owner listing) }
          {
            rental-count: (+ u1 (get rental-count owner-history)),
            total-earned: (+ owner-amount (get total-earned owner-history)),
            total-spent: (get total-spent owner-history)
          }))
      
      (ok true))))

(define-public (end-rental (rental-id uint))
  (let ((listing (unwrap! (map-get? rental-listings { rental-id: rental-id }) (err ERR-RENTAL-NOT-FOUND)))
        (rental (unwrap! (map-get? active-rentals { rental-id: rental-id }) (err ERR-RENTAL-NOT-FOUND)))
        (current-time (get-current-time)))
    
    (asserts! (or (is-eq tx-sender (get owner listing))
                  (is-eq tx-sender (get renter rental))
                  (>= current-time (get rental-end rental))) (err ERR-NOT-AUTHORIZED))
    
    (map-delete active-rentals { rental-id: rental-id })
    
    (map-set rental-listings
      { rental-id: rental-id }
      {
        owner: (get owner listing),
        renter: none,
        hourly-rate: (get hourly-rate listing),
        max-rental-period: (get max-rental-period listing),
        subscription-end-time: (get subscription-end-time listing),
        created-at: (get created-at listing),
        active: true,
        currently-rented: false
      })
    
    (ok true)))

(define-public (cancel-rental-listing (rental-id uint))
  (let ((listing (unwrap! (map-get? rental-listings { rental-id: rental-id }) (err ERR-RENTAL-NOT-FOUND))))
    
    (asserts! (is-eq tx-sender (get owner listing)) (err ERR-NOT-AUTHORIZED))
    (asserts! (get active listing) (err ERR-RENTAL-NOT-FOUND))
    (asserts! (not (get currently-rented listing)) (err ERR-ALREADY-RENTED))
    
    (map-set rental-listings
      { rental-id: rental-id }
      {
        owner: (get owner listing),
        renter: (get renter listing),
        hourly-rate: (get hourly-rate listing),
        max-rental-period: (get max-rental-period listing),
        subscription-end-time: (get subscription-end-time listing),
        created-at: (get created-at listing),
        active: false,
        currently-rented: false
      })
    
    (ok true)))

(define-public (update-rental-rate (rental-id uint) (new-hourly-rate uint))
  (let ((listing (unwrap! (map-get? rental-listings { rental-id: rental-id }) (err ERR-RENTAL-NOT-FOUND))))
    
    (asserts! (is-eq tx-sender (get owner listing)) (err ERR-NOT-AUTHORIZED))
    (asserts! (get active listing) (err ERR-RENTAL-NOT-FOUND))
    (asserts! (not (get currently-rented listing)) (err ERR-ALREADY-RENTED))
    (asserts! (> new-hourly-rate u0) (err ERR-INVALID-RENTAL-PERIOD))
    
    (map-set rental-listings
      { rental-id: rental-id }
      {
        owner: (get owner listing),
        renter: (get renter listing),
        hourly-rate: new-hourly-rate,
        max-rental-period: (get max-rental-period listing),
        subscription-end-time: (get subscription-end-time listing),
        created-at: (get created-at listing),
        active: true,
        currently-rented: false
      })
    
    (ok true)))

(define-read-only (get-rental-listing (rental-id uint))
  (map-get? rental-listings { rental-id: rental-id }))

(define-read-only (get-active-rental (rental-id uint))
  (map-get? active-rentals { rental-id: rental-id }))

(define-read-only (get-user-rental-stats (user principal))
  (map-get? user-rental-history { user: user }))

(define-read-only (calculate-rental-cost (rental-id uint) (hours uint))
  (match (map-get? rental-listings { rental-id: rental-id })
    listing
    (let ((total-cost (* (get hourly-rate listing) hours))
          (fee (/ (* total-cost RENTAL-FEE-PERCENT) u100)))
      (some { total-cost: total-cost, platform-fee: fee, owner-receives: (- total-cost fee) }))
    none))

(define-read-only (is-rental-active (rental-id uint))
  (match (map-get? active-rentals { rental-id: rental-id })
    rental
    (< (get-current-time) (get rental-end rental))
    false))

(define-read-only (get-rental-time-remaining (rental-id uint))
  (match (map-get? active-rentals { rental-id: rental-id })
    rental
    (let ((current-time (get-current-time))
          (end-time (get rental-end rental)))
      (if (> end-time current-time)
          (some (- end-time current-time))
          (some u0)))
    none))

(define-public (cleanup-expired-rentals (rental-ids (list 10 uint)))
  (ok (map cleanup-expired-rental rental-ids)))

(define-private (cleanup-expired-rental (rental-id uint))
  (match (map-get? active-rentals { rental-id: rental-id })
    rental
    (if (>= (get-current-time) (get rental-end rental))
        (begin
          (map-delete active-rentals { rental-id: rental-id })
          (match (map-get? rental-listings { rental-id: rental-id })
            listing
            (map-set rental-listings
              { rental-id: rental-id }
              {
                owner: (get owner listing),
                renter: none,
                hourly-rate: (get hourly-rate listing),
                max-rental-period: (get max-rental-period listing),
                subscription-end-time: (get subscription-end-time listing),
                created-at: (get created-at listing),
                active: true,
                currently-rented: false
              })
            false)
          true)
        false)
    false))