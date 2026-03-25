# Transfer Model Refactor Plan

## Current State

### How It Works Today

**TransferRule** is a SwiftData model with:
- `name` — display name
- `vendor: Vendor?` — optional vendor to match transactions by (via `vendor.filterText` substring match on `transaction.payee`)
- `sourceAccountId: Int?` — the account that will fund the transfer
- `targetAccountId: Int` — the credit card account being paid
- `priority: Int` — higher priority rules match first

**Transaction matching (in `WeeklyPaydownModel.transferBreakdown`):**
1. Get all rules for the selected credit card (`targetAccountId`)
2. Sort rules by priority (highest first)
3. For each period transaction, iterate rules looking for a vendor match (`transaction.payee` contains `vendor.filterText`)
4. First vendor match wins → transaction is assigned to that rule
5. Unmatched transactions fall to the default rule (where `vendor == nil`)
6. The paydown view shows a "Transfer Breakdown" with per-rule totals

**What this tells you:** "For this period's spending, here's how much each source account owes, broken down by which vendor-matching rule caught the transactions."

### What's Missing / Gaps

1. **No identification of actual transfer transactions.** When a transfer payment actually happens (e.g., a checking account sends $500 to the credit card), that transaction shows up in the Lunch Money data — but the app has no way to recognize it. There's no matching of "this transaction IS the transfer" vs "this transaction NEEDS a transfer."

2. **No distinction between "needs transfer" and "covered by transfer."** All period transactions are just bucketed by rule, but there's no tracking of whether the transfer has actually occurred. The breakdown shows what SHOULD be transferred, not what HAS been.

3. **Rules are vendor→source mappings only.** A rule says "Amazon purchases should be paid from Account X" — but it doesn't say "a transfer from Account X looks like a transaction named 'TRANSFER FROM CHECKING'" on the credit card.

4. **No transfer transaction pattern matching.** Transfer payments on a credit card typically show up as credits with recognizable names (e.g., "ONLINE PAYMENT - THANK YOU", "AUTOPAY", "ACH PAYMENT"). There's no way to define what a transfer looks like as a transaction.

5. **Catch-all rule exists but is implicit.** The default rule (`vendor == nil`) acts as a catch-all, which is good. But the concept could be clearer — it's a "everything else gets paid from this account" rule.

6. **No reconciliation.** You can't see "Rule X says I owe $300 from checking, and I can see a $300 transfer already posted."

---

## Vision

The transfer system should answer two questions:
1. **What needs to be transferred?** — Based on spending, which source accounts owe how much?
2. **What has been transferred?** — Which transfer payments have actually arrived?

### Core Concepts

- **Spending Rule**: "Transactions matching [pattern] should be covered by [source account]" (this is roughly what TransferRule does today)
- **Transfer Pattern**: "A transfer payment from [source account] looks like [pattern] on the credit card statement" (NEW)
- **Transfer Match**: Linking an actual credit transaction to a transfer pattern (NEW)

---

## Proposed Changes

### Phase 1: Transfer Pattern Recognition

**Goal:** Identify which credit transactions ARE transfer payments.

**New model: `TransferPattern`** (or extend `TransferRule`)
```
TransferPattern:
  - name: String              // e.g., "Checking Payment"
  - matchText: String         // substring/regex to match on transaction payee
  - matchType: enum           // .substring | .regex
  - sourceAccountId: Int      // which account this transfer comes from
  - targetAccountId: Int      // which account receives it
```

**How it works:**
- When viewing a period, scan credit transactions (negative `toBase`) for transfer pattern matches
- A credit transaction matching a transfer pattern is tagged as a "transfer payment" rather than a regular spend

**UI changes:**
- New section in the paydown view: "Transfers Received" showing matched transfer transactions
- Transfer transactions excluded from the spending breakdown (they're payments, not charges)
- Settings page to manage transfer patterns

### Phase 2: Spending Rules (Refactor TransferRule)

**Goal:** Clean up the existing TransferRule into a clearer "spending rule" concept.

**Rename `TransferRule` → `SpendingRule`** (or keep name but clarify purpose):
```
SpendingRule:
  - name: String
  - vendor: Vendor?           // match spending transactions by vendor
  - matchText: String?        // NEW: direct text match (alternative to vendor)
  - matchType: enum           // .substring | .regex
  - sourceAccountId: Int?     // which account covers this spending
  - targetAccountId: Int      // the credit card
  - priority: Int             // higher = matched first
  - isCatchAll: Bool          // NEW: explicit catch-all flag (replaces vendor == nil convention)
```

**Changes from today:**
- Add `matchText` as an alternative to vendor-based matching. Sometimes you want to match transactions directly without creating a vendor first.
- Add explicit `isCatchAll` flag instead of relying on `vendor == nil`.
- Vendor matching stays as-is (vendor.filterText) for backward compatibility.

### Phase 3: Reconciliation View

**Goal:** Show what's been transferred vs. what's owed.

**New UI section in paydown: "Transfer Reconciliation"**
```
Source Account    | Owed (from spending rules) | Received (from transfer patterns) | Difference
Checking         | $450                       | $500                              | +$50
Savings          | $120                       | $0                                | -$120
```

**How it works:**
- "Owed" = sum of spending rule breakdowns per source account (what exists today)
- "Received" = sum of matched transfer payment credits per source account (from Phase 1)
- "Difference" = received - owed (positive = overpaid, negative = still owe)

### Phase 4: Transaction Tagging (Optional/Future)

**Goal:** Allow manual override for edge cases.

- In transaction detail, allow manually tagging a transaction as "covered by [source account]" independent of rules
- Allow manually marking a credit as a "transfer from [source account]" if auto-matching doesn't catch it
- These manual tags override automatic matching

---

## Migration Path

| Step | What Changes | Breaking? |
|------|-------------|-----------|
| 1a | Add `TransferPattern` model | No — new model, no existing data affected |
| 1b | Scan credits for transfer matches in paydown view | No — additive UI |
| 1c | Exclude transfer credits from spending breakdown | **Behavior change** — spending totals will decrease (correctly) |
| 2a | Add `matchText`/`matchType` to `TransferRule` | No — optional new fields |
| 2b | Add `isCatchAll` flag, migrate `vendor == nil` rules | No — backward compatible |
| 3 | Add reconciliation section to paydown | No — additive UI |
| 4 | Add manual transaction tagging | No — additive |

### Data Model Changes

**New SwiftData model:**
```swift
@Model
public final class TransferPattern {
    public var id: UUID
    public var name: String
    public var matchText: String
    public var matchType: MatchType  // .substring or .regex
    public var sourceAccountId: Int
    public var targetAccountId: Int
    public var createdAt: Date
}

public enum MatchType: String, Codable {
    case substring
    case regex
}
```

**TransferRule additions:**
```swift
// New optional fields
public var matchText: String?       // alternative to vendor-based matching
public var matchType: MatchType?
public var isCatchAll: Bool         // explicit flag
```

---

## What to Build First

**Recommended order:** Phase 1 → Phase 3 → Phase 2 → Phase 4

**Phase 1 is the biggest gap.** Right now there's no way to distinguish "I bought groceries" from "my checking account paid the credit card." Both show up as transactions, but they mean fundamentally different things. Once transfer payments are identifiable, the paydown calculation becomes much more accurate, and reconciliation (Phase 3) follows naturally.

Phase 2 (spending rule cleanup) is a nice-to-have that makes the existing system cleaner but doesn't add new capability.

Phase 4 is for edge cases and can wait.
