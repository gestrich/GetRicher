# Transfer Rules — Proposal (v2)

## Core Concepts (Two Separate Models)

### 1. Vendor (reusable transaction matcher)

A long-lived record that identifies a type of transaction. Reusable across future features — not tied to transfers specifically.

```swift
@Model
public final class Vendor {
    public var id: UUID
    public var name: String              // User-friendly label, e.g. "Costco"
    public var filterText: String        // Substring match against transaction payee
    public var accountId: Int?           // Lunch Money account this vendor applies to
    public var createdAt: Date
}
```

**Matching:** Case-insensitive substring of `transaction.payee`. A transaction matches the first vendor (by priority/specificity) whose `filterText` is found in the payee, scoped to the same account.

### 2. TransferRule (payment routing, account-specific)

Defines how to pay for transactions — either for a specific vendor or as the default catch-all.

```swift
@Model
public final class TransferRule {
    public var id: UUID
    public var name: String              // Display label
    public var vendor: Vendor?           // nil = default catch-all for the account
    public var sourceAccountId: Int?     // Account to pay FROM (e.g., checking)
    public var targetAccountId: Int      // Account this rule belongs TO (the credit card)
    public var priority: Int             // For ordering (default = lowest)
    public var createdAt: Date
}
```

**Key points:**
- `vendor == nil` → default/catch-all rule (captures all unmatched transactions)
- Each target account has at most one default rule (`vendor == nil`)
- `sourceAccountId` is where money comes FROM
- `targetAccountId` is the credit card being paid down
- Rules are **account-specific** — managed from within an account's view

### Relationship

```
Vendor (reusable matcher)          TransferRule (account-specific routing)
┌─────────────────────┐            ┌──────────────────────────────┐
│ name: "Costco"      │◄───────────│ vendor: Costco               │
│ filterText: "COSTCO"│            │ sourceAccount: Business Chk  │
│ accountId: Chase     │            │ targetAccount: Chase Sapphire│
└─────────────────────┘            └──────────────────────────────┘
                                   ┌──────────────────────────────┐
              (no vendor) ─────────│ vendor: nil (DEFAULT)        │
                                   │ sourceAccount: Personal Chk  │
                                   │ targetAccount: Chase Sapphire│
                                   └──────────────────────────────┘
```

## Weekly Paydown With Transfer Rules

```
Weekly Paydown — Chase Sapphire
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Transfers:
  Personal Checking → Chase    $847.23  (default — 12 transactions)
  Business Checking → Chase    $234.50  (Costco, AWS — 3 transactions)
  Savings → Chase               $50.00  (Emergency Fund — 1 transaction)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Paydown                 $1,131.73
```

## UI

### Creating Vendors (long-press on transaction)
- Long-press transaction row → "Create Vendor"
- Pre-fills `name` and `filterText` from `transaction.payee`
- Pre-fills `accountId` from `transaction.plaidAccountId`

### Managing Rules (from within an account)
- When viewing an account (Dashboard or Weekly Paydown with account selected), there's a "Transfer Rules" option (toolbar button or section)
- Shows rules for that account: default rule + vendor-specific rules
- Add/edit/delete rules
- Each rule: pick a vendor (or mark as default), pick source account

### Transfer Rule Edit View
- Vendor picker (from vendors matching this account, or "Default / All Transactions")
- Source account picker
- Name auto-fills from vendor name (editable)

### Vendor Edit View
- Name
- Filter text (with live preview: "Matches N transactions")
- Account (pre-filled, usually not changed)

## Data Layer Placement

Both models go in **PersistenceService** (SwiftData `@Model` types):
- `FinancePackage/Sources/services/PersistenceService/Vendor.swift`
- `FinancePackage/Sources/services/PersistenceService/TransferRule.swift`

Matching logic goes in **WeeklyPaydownModel** (Apps layer) since it's view-specific calculation.

## Implementation Phases

### Phase 1: Vendor + TransferRule models + CRUD UI
- SwiftData models in PersistenceService
- Register in ModelContainer
- VendorEditView, TransferRuleEditView, TransferRulesListView
- Long-press context menu on transactions
- Access rules from account view

### Phase 2: Paydown Integration
- Group transactions by matched transfer rule
- Update PaydownCalculation for per-rule breakdowns
- Update WeeklyPaydownView to show transfer groups

### Phase 3: Polish
- Demo data with sample vendors/rules
- Live match preview
- UI tests + screenshots
