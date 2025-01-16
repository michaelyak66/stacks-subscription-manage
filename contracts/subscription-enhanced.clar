;; title: subscription-enhanced

;; Import the base contract
(as-contract (contract-call? .subscription subscribe u19))
(as-contract (contract-call? .subscription renew))
(define-constant TOKEN-LOCK-DURATION 2592000) ;; 30 days in seconds
(define-map subscriptions { user: principal } { end-time: uint, tokens-locked:uint })
(define-map subscription-tiers { tier-id: uint } { price: uint, duration: uint, benefits: (string-utf8 64) }) ;; Add tier definitions
(define-constant GRACE-PERIOD u259200) ;; 3 days in seconds

