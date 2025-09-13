(define-constant ERR-NOT-AUTHORIZED u1001)
(define-constant ERR-LISTING-NOT-FOUND u1002)
(define-constant ERR-INSUFFICIENT-PAYMENT u1003)
(define-constant ERR-NO-ACTIVE-SUBSCRIPTION u1004)
(define-constant ERR-INVALID-PRICE u1005)
(define-constant ERR-CANNOT-BUY-OWN-LISTING u1006)
(define-constant ERR-SUBSCRIPTION-EXPIRED u1007)

(define-constant TRANSFER-FEE-PERCENT u5)
(define-constant MIN-REMAINING-TIME u86400)

(define-map transfer-listings
  { listing-id: uint }
  { 
    seller: principal,
    price: uint,
    subscription-end-time: uint,
    tokens-locked: uint,
    created-at: uint,
    active: bool
  })

(define-map listing-counter
  { counter: (string-ascii 8) }
  { value: uint })

(define-map user-listings
  { user: principal }
  { listing-ids: (list 10 uint), count: uint })

(define-map subscription-ownership
  { user: principal }
  { 
    end-time: uint,
    tokens-locked: uint,
    original-owner: principal,
    transfer-count: uint
  })

(define-read-only (get-next-listing-id)
  (+ u1 (default-to u0 (get value (map-get? listing-counter { counter: "listings" })))))

(define-read-only (get-current-time)
  (unwrap-panic (get-stacks-block-info? time u0)))

(define-public (get-subscription-details (user principal))
  (contract-call? .subscription-enhanced get-subscription-info user))

(define-public (create-transfer-listing (asking-price uint))
  (let ((current-time (get-current-time))
        (listing-id (get-next-listing-id))
        (subscription-info (unwrap! (get-subscription-details tx-sender) (err ERR-NO-ACTIVE-SUBSCRIPTION))))
    
    (asserts! (> asking-price u0) (err ERR-INVALID-PRICE))
    (asserts! (> (get end-time subscription-info) (+ current-time MIN-REMAINING-TIME)) (err ERR-SUBSCRIPTION-EXPIRED))
    
    (map-set transfer-listings
      { listing-id: listing-id }
      {
        seller: tx-sender,
        price: asking-price,
        subscription-end-time: (get end-time subscription-info),
        tokens-locked: (get tokens-locked subscription-info),
        created-at: current-time,
        active: true
      })
    
    (map-set listing-counter { counter: "listings" } { value: listing-id })
    
    (let ((user-data (default-to { listing-ids: (list), count: u0 } 
                     (map-get? user-listings { user: tx-sender }))))
      (map-set user-listings
        { user: tx-sender }
        {
          listing-ids: (unwrap! (as-max-len? (append (get listing-ids user-data) listing-id) u10) (err u999)),
          count: (+ u1 (get count user-data))
        }))
    
    (ok listing-id)))

(define-public (purchase-subscription-transfer (listing-id uint))
  (let ((listing (unwrap! (map-get? transfer-listings { listing-id: listing-id }) (err ERR-LISTING-NOT-FOUND)))
        (current-time (get-current-time)))
    
    (asserts! (get active listing) (err ERR-LISTING-NOT-FOUND))
    (asserts! (not (is-eq tx-sender (get seller listing))) (err ERR-CANNOT-BUY-OWN-LISTING))
    (asserts! (> (get subscription-end-time listing) current-time) (err ERR-SUBSCRIPTION-EXPIRED))
    
    (let ((transfer-fee (/ (* (get price listing) TRANSFER-FEE-PERCENT) u100))
          (seller-amount (- (get price listing) transfer-fee)))
      
      (try! (stx-transfer? (get price listing) tx-sender (as-contract tx-sender)))
      (try! (as-contract (stx-transfer? seller-amount tx-sender (get seller listing))))
      
      (map-set subscription-ownership
        { user: tx-sender }
        {
          end-time: (get subscription-end-time listing),
          tokens-locked: (get tokens-locked listing),
          original-owner: (get seller listing),
          transfer-count: u1
        })
      
      (unwrap! (contract-call? .subscription-enhanced transfer-subscription tx-sender (get subscription-end-time listing) (get tokens-locked listing)) (err ERR-NO-ACTIVE-SUBSCRIPTION))
      
      (map-set transfer-listings
        { listing-id: listing-id }
        {
          seller: (get seller listing),
          price: (get price listing),
          subscription-end-time: (get subscription-end-time listing),
          tokens-locked: (get tokens-locked listing),
          created-at: (get created-at listing),
          active: false
        })
      
      (ok true))))

(define-public (cancel-transfer-listing (listing-id uint))
  (let ((listing (unwrap! (map-get? transfer-listings { listing-id: listing-id }) (err ERR-LISTING-NOT-FOUND))))
    
    (asserts! (is-eq tx-sender (get seller listing)) (err ERR-NOT-AUTHORIZED))
    (asserts! (get active listing) (err ERR-LISTING-NOT-FOUND))
    
    (map-set transfer-listings
      { listing-id: listing-id }
      {
        seller: (get seller listing),
        price: (get price listing),
        subscription-end-time: (get subscription-end-time listing),
        tokens-locked: (get tokens-locked listing),
        created-at: (get created-at listing),
        active: false
      })
    
    (ok true)))

(define-public (update-listing-price (listing-id uint) (new-price uint))
  (let ((listing (unwrap! (map-get? transfer-listings { listing-id: listing-id }) (err ERR-LISTING-NOT-FOUND))))
    
    (asserts! (is-eq tx-sender (get seller listing)) (err ERR-NOT-AUTHORIZED))
    (asserts! (get active listing) (err ERR-LISTING-NOT-FOUND))
    (asserts! (> new-price u0) (err ERR-INVALID-PRICE))
    
    (map-set transfer-listings
      { listing-id: listing-id }
      {
        seller: (get seller listing),
        price: new-price,
        subscription-end-time: (get subscription-end-time listing),
        tokens-locked: (get tokens-locked listing),
        created-at: (get created-at listing),
        active: true
      })
    
    (ok true)))

(define-read-only (get-listing-details (listing-id uint))
  (map-get? transfer-listings { listing-id: listing-id }))

(define-read-only (get-user-listings (user principal))
  (map-get? user-listings { user: user }))

(define-read-only (get-active-listings-count)
  (default-to u0 (get value (map-get? listing-counter { counter: "listings" }))))

(define-read-only (calculate-remaining-value (listing-id uint))
  (match (map-get? transfer-listings { listing-id: listing-id })
    listing
    (let ((current-time (get-current-time))
          (remaining-time (- (get subscription-end-time listing) current-time)))
      (if (> remaining-time u0)
          (some remaining-time)
          none))
    none))

(define-read-only (get-transfer-fee (price uint))
  (/ (* price TRANSFER-FEE-PERCENT) u100))

(define-read-only (get-marketplace-stats)
  {
    total-listings: (get-active-listings-count),
    transfer-fee-percent: TRANSFER-FEE-PERCENT,
    min-remaining-time: MIN-REMAINING-TIME
  })

(define-public (batch-cancel-expired-listings (listing-ids (list 10 uint)))
  (let ((current-time (get-current-time)))
    (ok (map cancel-if-expired listing-ids))))

(define-private (cancel-if-expired (listing-id uint))
  (match (map-get? transfer-listings { listing-id: listing-id })
    listing
    (if (and (get active listing) 
             (<= (get subscription-end-time listing) (get-current-time)))
        (map-set transfer-listings
          { listing-id: listing-id }
          {
            seller: (get seller listing),
            price: (get price listing),
            subscription-end-time: (get subscription-end-time listing),
            tokens-locked: (get tokens-locked listing),
            created-at: (get created-at listing),
            active: false
          })
        false)
    false))

(define-public (emergency-cancel-all-user-listings)
  (match (map-get? user-listings { user: tx-sender })
    user-data
    (begin
      (map cancel-user-listing (get listing-ids user-data))
      (ok true))
    (ok false)))

(define-private (cancel-user-listing (listing-id uint))
  (match (map-get? transfer-listings { listing-id: listing-id })
    listing
    (if (and (is-eq (get seller listing) tx-sender) (get active listing))
        (map-set transfer-listings
          { listing-id: listing-id }
          {
            seller: (get seller listing),
            price: (get price listing),
            subscription-end-time: (get subscription-end-time listing),
            tokens-locked: (get tokens-locked listing),
            created-at: (get created-at listing),
            active: false
          })
        false)
    false))