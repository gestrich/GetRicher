# Transfer Rules, Vendors & Categories — Proposal (v3)

## Core Concepts (Three Models)

### 1. Category (global, user-editable)

App-wide transaction categories. Not account-specific — shared across all accounts. Users can create, edit, and assign categories to transactions.

```swift
@Model
public final class Category {
    public var id: UUID
    public var name: String              // e.g. "Groceries", "Shopping", "Dining"
    public var colorHex: String?         // Optional color for UI
    public var createdAt: Date
}
```

**Relationship to transactions:** The existing `Transaction` model gains an optional relationship to `Category`. This is a local/app-level category — independent of Lunch Money's `categoryName` field (which is read-only from the API).

```swift
// Added to Transaction model:
@Relationship public var localCategory: Category?
```

**UI:**
- Categories managed from a global settings/management screen (not account-specific)
- Assign a category to a transaction via the transaction detail view or long-press menu
- Categories can be used for filtering, grouping, and future reporting

### 2. Vendor (reusable transaction matcher)

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

All three models go in **PersistenceService** (SwiftData `@Model` types):
- `FinancePackage/Sources/services/PersistenceService/Category.swift`
- `FinancePackage/Sources/services/PersistenceService/Vendor.swift`
- `FinancePackage/Sources/services/PersistenceService/TransferRule.swift`

`Transaction` model updated with `localCategory` relationship.

Matching logic goes in **WeeklyPaydownModel** (Apps layer) since it's view-specific calculation.

## UI Summary

| Screen | Scope | Access From |
|--------|-------|-------------|
| CategoryListView | Global (all accounts) | Settings or dedicated tab |
| CategoryEditView | Global | CategoryListView, transaction long-press |
| VendorEditView | Account-scoped | Transaction long-press, VendorListView |
| TransferRulesListView | Account-scoped | Within account view (toolbar/section) |
| TransferRuleEditView | Account-scoped | TransferRulesListView |

**Long-press on transaction** context menu:
- "Create Vendor" → VendorEditView (pre-filled from payee)
- "Set Category" → Category picker
- "Assign Category" could also live in TransactionDetailView

## Implementation Phases

### Phase 1: Category model + UI
- Category SwiftData model in PersistenceService
- Add `localCategory` relationship to Transaction model
- Register Category in ModelContainer
- CategoryListView + CategoryEditView (global, from Settings)
- Category assignment on transactions (detail view + long-press)

### Phase 2: Vendor model + UI
- Vendor SwiftData model in PersistenceService
- Register in ModelContainer
- VendorEditView (create from transaction long-press)
- VendorListView (browse/edit vendors for an account)

### Phase 3: TransferRule model + UI
- TransferRule SwiftData model in PersistenceService
- Register in ModelContainer
- TransferRulesListView + TransferRuleEditView
- Access from within account view

### Phase 4: Paydown Integration
- Group transactions by matched transfer rule
- Update PaydownCalculation for per-rule breakdowns
- Update WeeklyPaydownView to show transfer groups

### Phase 5: Polish
- Demo data with sample categories, vendors, rules
- Live match preview in vendor edit
- UI tests + screenshots
