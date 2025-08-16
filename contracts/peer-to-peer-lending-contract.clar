(define-constant CONTRACT_OWNER tx-sender)

(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_LOAN_NOT_FOUND (err u1002))
(define-constant ERR_LOAN_ALREADY_FUNDED (err u1003))
(define-constant ERR_LOAN_NOT_FUNDED (err u1004))
(define-constant ERR_INSUFFICIENT_FUNDS (err u1005))
(define-constant ERR_LOAN_EXPIRED (err u1006))
(define-constant ERR_INVALID_AMOUNT (err u1007))
(define-constant ERR_SELF_FUNDING (err u1008))
(define-constant ERR_ALREADY_REPAID (err u1009))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u1010))
(define-constant ERR_COLLATERAL_SEIZED (err u1011))

(define-data-var loan-counter uint u0)

(define-map loans
  uint
  {
    borrower: principal,
    lender: (optional principal),
    amount: uint,
    interest-rate: uint,
    duration: uint,
    collateral-amount: uint,
    created-at: uint,
    funded-at: (optional uint),
    repaid-at: (optional uint),
    status: (string-ascii 20),
    collateral-seized: bool
  }
)

(define-map user-balances principal uint)

(define-map collateral-deposits principal uint)

(define-private (get-balance (user principal))
  (default-to u0 (map-get? user-balances user))
)

(define-private (get-collateral (user principal))
  (default-to u0 (map-get? collateral-deposits user))
)

(define-private (set-balance (user principal) (amount uint))
  (map-set user-balances user amount)
)

(define-private (set-collateral (user principal) (amount uint))
  (map-set collateral-deposits user amount)
)

(define-private (calculate-repayment-amount (amount uint) (interest-rate uint))
  (+ amount (/ (* amount interest-rate) u10000))
)

(define-read-only (get-loan (loan-id uint))
  (map-get? loans loan-id)
)

(define-read-only (get-user-balance (user principal))
  (get-balance user)
)

(define-read-only (get-user-collateral (user principal))
  (get-collateral user)
)

(define-read-only (get-current-loan-id)
  (var-get loan-counter)
)

(define-public (deposit-funds (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (set-balance tx-sender (+ (get-balance tx-sender) amount))
    (ok amount)
  )
)

(define-public (withdraw-funds (amount uint))
  (let
    (
      (current-balance (get-balance tx-sender))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_FUNDS)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (set-balance tx-sender (- current-balance amount))
    (ok amount)
  )
)

(define-public (deposit-collateral (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (set-collateral tx-sender (+ (get-collateral tx-sender) amount))
    (ok amount)
  )
)

(define-public (withdraw-collateral (amount uint))
  (let
    (
      (current-collateral (get-collateral tx-sender))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= current-collateral amount) ERR_INSUFFICIENT_COLLATERAL)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (set-collateral tx-sender (- current-collateral amount))
    (ok amount)
  )
)

(define-public (create-loan-request (amount uint) (interest-rate uint) (duration uint) (collateral-amount uint))
  (let
    (
      (loan-id (+ (var-get loan-counter) u1))
      (current-collateral (get-collateral tx-sender))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> duration u0) ERR_INVALID_AMOUNT)
    (asserts! (>= current-collateral collateral-amount) ERR_INSUFFICIENT_COLLATERAL)
    
    (map-set loans loan-id
      {
        borrower: tx-sender,
        lender: none,
        amount: amount,
        interest-rate: interest-rate,
        duration: duration,
        collateral-amount: collateral-amount,
        created-at: stacks-block-height,
        funded-at: none,
        repaid-at: none,
        status: "open",
        collateral-seized: false
      }
    )
    
    (set-collateral tx-sender (- current-collateral collateral-amount))
    (var-set loan-counter loan-id)
    (ok loan-id)
  )
)

(define-public (fund-loan (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
      (lender-balance (get-balance tx-sender))
    )
    (asserts! (is-eq (get status loan) "open") ERR_LOAN_ALREADY_FUNDED)
    (asserts! (not (is-eq tx-sender (get borrower loan))) ERR_SELF_FUNDING)
    (asserts! (>= lender-balance (get amount loan)) ERR_INSUFFICIENT_FUNDS)
    
    (set-balance tx-sender (- lender-balance (get amount loan)))
    (set-balance (get borrower loan) (+ (get-balance (get borrower loan)) (get amount loan)))
    
    (map-set loans loan-id
      (merge loan {
        lender: (some tx-sender),
        funded-at: (some stacks-block-height),
        status: "funded"
      })
    )
    
    (ok loan-id)
  )
)

(define-public (repay-loan (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
      (repayment-amount (calculate-repayment-amount (get amount loan) (get interest-rate loan)))
      (borrower-balance (get-balance tx-sender))
      (lender (unwrap! (get lender loan) ERR_LOAN_NOT_FUNDED))
    )
    (asserts! (is-eq tx-sender (get borrower loan)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status loan) "funded") ERR_ALREADY_REPAID)
    (asserts! (>= borrower-balance repayment-amount) ERR_INSUFFICIENT_FUNDS)
    
    (set-balance tx-sender (- borrower-balance repayment-amount))
    (set-balance lender (+ (get-balance lender) repayment-amount))
    (set-collateral tx-sender (+ (get-collateral tx-sender) (get collateral-amount loan)))
    
    (map-set loans loan-id
      (merge loan {
        repaid-at: (some stacks-block-height),
        status: "repaid"
      })
    )
    
    (ok repayment-amount)
  )
)

(define-public (seize-collateral (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
      (lender (unwrap! (get lender loan) ERR_LOAN_NOT_FUNDED))
      (funded-at (unwrap! (get funded-at loan) ERR_LOAN_NOT_FUNDED))
      (expiration-block (+ funded-at (get duration loan)))
    )
    (asserts! (is-eq tx-sender lender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status loan) "funded") ERR_ALREADY_REPAID)
    (asserts! (>= stacks-block-height expiration-block) ERR_LOAN_EXPIRED)
    (asserts! (not (get collateral-seized loan)) ERR_COLLATERAL_SEIZED)
    
    (set-balance lender (+ (get-balance lender) (get collateral-amount loan)))
    
    (map-set loans loan-id
      (merge loan {
        status: "defaulted",
        collateral-seized: true
      })
    )
    
    (ok (get collateral-amount loan))
  )
)

(define-public (cancel-loan-request (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get borrower loan)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status loan) "open") ERR_LOAN_ALREADY_FUNDED)
    
    (set-collateral tx-sender (+ (get-collateral tx-sender) (get collateral-amount loan)))
    
    (map-set loans loan-id
      (merge loan { status: "cancelled" })
    )
    
    (ok loan-id)
  )
)

(define-read-only (calculate-loan-repayment (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
    )
    (ok (calculate-repayment-amount (get amount loan) (get interest-rate loan)))
  )
)

(define-read-only (is-loan-expired (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
      (funded-at (get funded-at loan))
    )
    (match funded-at
      some-funded-at (ok (>= stacks-block-height (+ some-funded-at (get duration loan))))
      (err u4001)
    )
  )
)

(define-read-only (get-loan-status (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
    )
    (ok (get status loan))
  )
)

(define-read-only (get-active-loans (user principal))
  (let
    (
      (counter (var-get loan-counter))
    )
    (filter-loans-by-status user "funded" u1 counter)
  )
)

(define-private (filter-loans-by-status (user principal) (target-status (string-ascii 20)) (start uint) (end uint))
  (fold check-loan-for-user (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) (list))
)

(define-private (check-loan-for-user (loan-id uint) (acc (list 10 uint)))
  (let
    (
      (loan-opt (map-get? loans loan-id))
    )
    (match loan-opt
      some-loan 
        (if (and 
          (or (is-eq (get borrower some-loan) tx-sender) 
              (is-eq (unwrap-panic (get lender some-loan)) tx-sender))
          (is-eq (get status some-loan) "funded"))
          (unwrap-panic (as-max-len? (append acc loan-id) u10))
          acc)
      acc
    )
  )
)

(define-public (emergency-withdraw)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (try! (as-contract (stx-transfer? (stx-get-balance tx-sender) tx-sender CONTRACT_OWNER)))
    (ok true)
  )
)