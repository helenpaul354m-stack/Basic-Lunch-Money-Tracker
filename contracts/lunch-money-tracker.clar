
;; Basic cafeteria payment system with balance tracking and alerts

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-FUNDS (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant LOW-BALANCE-THRESHOLD u500) ;; 5.00 STX in microstx

(define-data-var contract-owner principal tx-sender)

(define-map student-balances principal uint)
(define-map meal-transactions
  { student: principal, block: uint }
  { amount: uint, meal-type: (string-ascii 32), timestamp: uint })

(define-read-only (get-balance (student principal))
  (default-to u0 (map-get? student-balances student)))

(define-read-only (is-low-balance (student principal))
  (< (get-balance student) LOW-BALANCE-THRESHOLD))

(define-read-only (get-contract-owner)
  (var-get contract-owner))

(define-public (add-funds (student principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (let ((current-balance (get-balance student)))
      (map-set student-balances student (+ current-balance amount))
      (ok (+ current-balance amount)))))

(define-public (purchase-meal (amount uint) (meal-type (string-ascii 32)))
  (let ((student tx-sender)
        (current-balance (get-balance tx-sender))
        (current-block stacks-block-height))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= current-balance amount) ERR-INSUFFICIENT-FUNDS)
    (map-set student-balances student (- current-balance amount))
    (map-set meal-transactions
      { student: student, block: current-block }
      { amount: amount, meal-type: meal-type, timestamp: stacks-block-height })
    (ok {
      new-balance: (- current-balance amount),
      low-balance-alert: (< (- current-balance amount) LOW-BALANCE-THRESHOLD)
    })))

(define-read-only (get-transaction (student principal) (block uint))
  (map-get? meal-transactions { student: student, block: block }))

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok new-owner)))
