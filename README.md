# 🏦 Peer-to-Peer Lending Smart Contract

💸 Decentralized lending platform built on Stacks blockchain with collateral management

## 🚀 Features

- 📝 **Loan Requests**: Borrowers can create loan requests with specified terms
- 💰 **Collateral Management**: Secure collateral deposits before loan creation
- 🤝 **Peer Funding**: Lenders can fund open loan requests
- ⏰ **Time-based Loans**: Configurable loan duration with automatic expiration
- 📊 **Interest Calculations**: Built-in interest rate calculations
- 🔒 **Collateral Seizure**: Automatic collateral seizure for defaulted loans
- 💳 **Balance Management**: Deposit and withdraw funds functionality

## 📋 Contract Functions

### 💵 Balance Management
- `deposit-funds(amount)` - Deposit STX into your lending balance
- `withdraw-funds(amount)` - Withdraw STX from your balance
- `get-user-balance(user)` - Check user's lending balance

### 🏛️ Collateral Management  
- `deposit-collateral(amount)` - Deposit STX as collateral
- `withdraw-collateral(amount)` - Withdraw available collateral
- `get-user-collateral(user)` - Check user's collateral balance

### 📝 Loan Operations
- `create-loan-request(amount, interest-rate, duration, collateral-amount)` - Create a new loan request
- `fund-loan(loan-id)` - Fund an open loan request
- `repay-loan(loan-id)` - Repay a funded loan with interest
- `cancel-loan-request(loan-id)` - Cancel an unfunded loan request
- `seize-collateral(loan-id)` - Seize collateral from defaulted loan

### 🔍 Read-Only Functions
- `get-loan(loan-id)` - Get loan details
- `calculate-loan-repayment(loan-id)` - Calculate total repayment amount
- `is-loan-expired(loan-id)` - Check if loan has expired
- `get-loan-status(loan-id)` - Get current loan status
- `get-active-loans(user)` - Get user's active loans

## 🎯 Usage Example

### 1️⃣ Setup Accounts

```clarity
;; Borrower deposits collateral
(contract-call? .peer-to-peer-lending-contract deposit-collateral u1000000)

;; Lender deposits funds  
(contract-call? .peer-to-peer-lending-contract deposit-funds u500000)
```

### 2️⃣ Create Loan Request

```clarity
;; Create loan: 500k STX, 10% interest, 144 blocks duration, 1M STX collateral
(contract-call? .peer-to-peer-lending-contract create-loan-request u500000 u1000 u144 u1000000)
```

### 3️⃣ Fund and Repay

```clarity
;; Lender funds the loan
(contract-call? .peer-to-peer-lending-contract fund-loan u1)

;; Borrower repays loan (550k STX = 500k + 10% interest)
(contract-call? .peer-to-peer-lending-contract repay-loan u1)
```

## ⚙️ Parameters

### Interest Rate
- Expressed in basis points (1% = 100, 10% = 1000)
- Applied to principal amount for total repayment

### Duration  
- Measured in blocks
- ~10 minutes per block on Stacks
- Example: 144 blocks ≈ 24 hours

### Collateral
- Must be deposited before creating loan requests
- Automatically locked when loan is created
- Released upon repayment or seized upon default

## 🛡️ Security Features

- ✅ **Collateral Requirements**: Borrowers must deposit collateral before requesting loans
- ✅ **Self-funding Prevention**: Borrowers cannot fund their own loans  
- ✅ **Balance Verification**: All transfers verified against available balances
- ✅ **Time-based Defaults**: Automatic collateral seizure for expired loans
- ✅ **Status Tracking**: Comprehensive loan status management

## 🏗️ Development

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Testing
```bash
clarinet test
```

### Deploy
```bash
clarinet deploy
```

## 📊 Loan States

| Status | Description |
|--------|-------------|
| `open` | 📋 Loan request created, awaiting funding |
| `funded` | 💰 Loan funded, awaiting repayment |
| `repaid` | ✅ Loan successfully repaid |
| `cancelled` | ❌ Loan request cancelled by borrower |
| `defaulted` | ⚠️ Loan expired, collateral seized |

## 🔧 Error Codes

- `u1001` - Unauthorized action
- `u1002` - Loan not found  
- `u1003` - Loan already funded
- `u1004` - Loan not funded
- `u1005` - Insufficient funds
- `u1006` - Loan expired
- `u1007` - Invalid amount
- `u1008` - Self-funding attempt
- `u1009` - Already repaid
- `u1010` - Insufficient collateral
- `u1011` - Collateral already seized

## 📄 License

MIT License - Built with ❤️ on Stacks
