;; --------------------------------------------------
;; Contract: SubChainFlexPro
;; Description: Advanced micropayment subscription protocol with admin governance, trials & analytics
;; --------------------------------------------------

(define-data-var plan-counter uint u1)
(define-data-var contract-admin principal tx-sender)

(define-map plans
  uint
  {
    provider: principal,
    fee: uint,
    interval: uint,
    metadata: (string-ascii 100),
    active: bool,
    free-trial: bool
  }
)

(define-map subscriptions
  { subscriber: principal, plan-id: uint }
  {
    start-block: uint,
    next-payment-block: uint,
    expiry-block: (optional uint),
    active: bool
  }
)

;; === Create Plan ===
(define-public (create-plan (fee uint) (interval uint) (metadata (string-ascii 100)) (free-trial bool))
  (let ((id (var-get plan-counter)))
    (begin
      (map-set plans id {
        provider: tx-sender,
        fee: fee,
        interval: interval,
        metadata: metadata,
        active: true,
        free-trial: free-trial
      })
      (var-set plan-counter (+ id u1))
      (ok id)
    )
  )
)

;; === Subscribe ===
(define-public (subscribe (plan-id uint) (expiry-block (optional uint)))
  (match (map-get? plans plan-id)
    plan
    (begin
      (asserts! (get active plan) (err u105))
      (if (get free-trial plan)
          (map-set subscriptions { subscriber: tx-sender, plan-id: plan-id } {
            start-block: stacks-block-height,
            next-payment-block: (+ stacks-block-height (get interval plan)),
            expiry-block: expiry-block,
            active: true
          })
          (begin
            (try! (stx-transfer? (get fee plan) tx-sender (get provider plan)))
            (map-set subscriptions { subscriber: tx-sender, plan-id: plan-id } {
              start-block: stacks-block-height,
              next-payment-block: (+ stacks-block-height (get interval plan)),
              expiry-block: expiry-block,
              active: true
            })
          )
      )
      (ok true)
    )
    (err u100)
  )
)

;; === Process Payment ===
(define-public (process-payment (subscriber principal) (plan-id uint))
  (match (map-get? subscriptions { subscriber: subscriber, plan-id: plan-id })
    sub
    (if (and (get active sub)
             (>= stacks-block-height (get next-payment-block sub))
             (or (is-none (get expiry-block sub))
                 (<= stacks-block-height (unwrap-panic (get expiry-block sub)))))
        (match (map-get? plans plan-id)
          plan
          (begin
            (asserts! (get active plan) (err u105))
            (try! (stx-transfer? (get fee plan) subscriber (get provider plan)))
            (map-set subscriptions { subscriber: subscriber, plan-id: plan-id } {
              start-block: (get start-block sub),
              next-payment-block: (+ stacks-block-height (get interval plan)),
              expiry-block: (get expiry-block sub),
              active: true
            })
            (ok true)
          )
          (err u101)
        )
        (err u102)
    )
    (err u103)
  )
)

;; === Cancel Subscription ===
(define-public (cancel-subscription (plan-id uint))
  (let ((key { subscriber: tx-sender, plan-id: plan-id }))
    (match (map-get? subscriptions key)
      sub
      (begin
        (map-set subscriptions key (merge sub { active: false }))
        (ok true)
      )
      (err u103)
    )
  )
)

;; === Toggle Plan Status (Provider) ===
(define-public (toggle-plan-status (plan-id uint))
  (match (map-get? plans plan-id)
    plan
    (begin
      (asserts! (is-eq tx-sender (get provider plan)) (err u106))
      (map-set plans plan-id (merge plan { active: (not (get active plan)) }))
      (ok (not (get active plan)))
    )
    (err u100)
  )
)

;; === Update Plan ===
(define-public (update-plan (plan-id uint) (fee uint) (interval uint) (metadata (string-ascii 100)) (free-trial bool))
  (match (map-get? plans plan-id)
    plan
    (begin
      (asserts! (is-eq tx-sender (get provider plan)) (err u106))
      (map-set plans plan-id {
        provider: (get provider plan),
        fee: fee,
        interval: interval,
        metadata: metadata,
        active: (get active plan),
        free-trial: free-trial
      })
      (ok true)
    )
    (err u100)
  )
)

;; === Transfer Plan Ownership ===
(define-public (transfer-plan (plan-id uint) (new-provider principal))
  (match (map-get? plans plan-id)
    plan
    (begin
      (asserts! (is-eq tx-sender (get provider plan)) (err u106))
      (map-set plans plan-id (merge plan { provider: new-provider }))
      (ok true)
    )
    (err u100)
  )
)

;; === Admin Remove Plan ===
(define-public (remove-plan (plan-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err u106))
    (map-delete plans plan-id)
    (ok true)
  )
)

;; === Admin Freeze Plan (Force Pause) ===
(define-public (freeze-plan (plan-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err u106))
    (match (map-get? plans plan-id)
      plan
      (begin
        (map-set plans plan-id (merge plan { active: false }))
        (ok true)
      )
      (err u100)
    )
  )
)

;; === Admin Remove Subscription ===
(define-public (remove-subscription (subscriber principal) (plan-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err u106))
    (map-delete subscriptions { subscriber: subscriber, plan-id: plan-id })
    (ok true)
  )
)

;; === Get Plan ===
(define-read-only (get-plan (plan-id uint))
  (ok (map-get? plans plan-id))
)

;; === Get Subscription ===
(define-read-only (get-subscription (subscriber principal) (plan-id uint))
  (ok (map-get? subscriptions { subscriber: subscriber, plan-id: plan-id }))
)

;; === Get My Active Subscriptions ===
;; NOTE: Clarity 1.x does not support 'map-keys'.
;; To get your active subscriptions, clients should keep track of their own subscriptions or iterate over all possible keys client-side.
;; The function (get-my-active-subscriptions) is not possible in Clarity 1.x.

;; === Admin Transfer ===
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err u106))
    (var-set contract-admin new-admin)
    (ok true)
  )
)

;; NOTE: Clarity 1.x does not support 'range' or map key enumeration.
;; To get all active plans, clients should iterate from 0 to (plan-counter - 1)
;; and call (get-plan id) for each, filtering for active plans client-side.
;; The function (list-active-plans) is not possible in Clarity 1.x.
