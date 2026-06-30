# Weekly Paydown Refactor — Transaction Types

> Status: **proposed** — awaiting your sign-off before any code changes.
> Backwards compatibility: **not required**. We delete old structures (`Vendor`,
> `TransferRule`, `RuleKind`, the per-source "Pay From Each Account" calc) and migrate the
> two rules we actually have (Cloud 9, PNC Payment) into the new model.

## Why we're doing this

Today's pieces grew organically and conflate things:
- `Vendor` (payee matcher) + `TransferRule` (`kind: transfer|payment`) are two structures doing
  one job: "identify a transaction and say what it is."
- The "amount to pay" got rebuilt as a per-source charge allocation, which **replaced** the
  balance-based number you actually wanted.

The refactor separates the two calculations you described and gives payments a real identity:

1. **Total Spend** — sum of transactions, bucketed by type (a transparency view).
2. **Payments Owed** — balance-based (current balance adjusted for period timing). The number you pay.

These are *different calculations of related ideas*, kept as **separate concepts** with **separate names** in the code.

---

## Terminology (these names are used verbatim in code)

| Term | Meaning |
|---|---|
| **TransactionType** | A user-defined classification of transactions (e.g. *Cloud 9*, *PNC Payment*). Replaces `Vendor` + `TransferRule` + `RuleKind`. Created/edited in-app. |
| **TransactionTypeKind** | What a type *is*: **`.spend`** (a purchase/refund — counts as spending) or **`.payment`** (a settlement that pays the card down — never counted as spending). |
| **payeePatterns** | The case-insensitive payee substrings that identify a type (e.g. `"Cloud 9"`, `"THANK YOU FOR YOUR PMT"`). Replaces `Vendor.filterText`. A type can have several. |
| **fundingAccountId** | On a `.spend` type only: the *other* account that pays for this spend (e.g. Cloud 9 → PNC Six Month Reserve). `nil` ⇒ paid from your **primary** payment. This is the "Cloud 9 from another account" feature, generalized. |
| **Other Spend** | The implicit bucket for `.spend` transactions that match no type. Funded from primary. Not a stored type — it's "everything not otherwise classified." |
| **classify(transaction)** | Resolve a transaction to its `TransactionType` (highest `priority` match wins) or `nil` ⇒ Other Spend. |
| **period** | The selected 7-day cycle `[start, end]` (e.g. last week 6/20–6/26). |
| **in-period pending** | Transactions dated within `period` that have **not posted** yet (so they're *not* in the balance). |
| **post-period posted** | Transactions dated **after** `period.end` that **have posted** (so they *are* in the balance, but belong to a later week). |
| **Total Spend** | Σ of all **non-payment** transactions in `period`, bucketed by type. |
| **Total Payments** | Σ of all **payment** transactions in `period`. |
| **Payments Owed** | Balance-based amount to pay: `current balance + in-period pending − post-period posted`, then split out funded types (Cloud 9). Payments are excluded from these adjustments. |

---

## Data model (FinanceCoreSDK)

Delete `Vendor`, `TransferRule`, `RuleKind`. Add:

```swift
enum TransactionTypeKind: String, Codable { case spend, payment }

struct TransactionType: Identifiable, Codable, LWWMergeable {
    let id: UUID
    var name: String                 // "Cloud 9", "PNC Payment", "Groceries", ...
    var kind: TransactionTypeKind    // .spend | .payment
    var fundingAccountId: Int?       // .spend only: another account that covers it (Cloud 9 → Reserve); nil = primary
    var targetAccountId: Int         // which credit card this type applies to
    var payeePatterns: [String]      // case-insensitive payee substrings
    var priority: Int                // higher matches first
    // LWW sync fields (kept from current work):
    var updatedAt: Date
    var isDeleted: Bool              // SwiftData mirror is `isTombstoned` (reserved-name fix stays)
}
```

`payment`-kind types ignore `fundingAccountId` (a payment isn't "funded by" anything — it's the settlement).

A transaction's type is **derived at calc time** by matching `payeePatterns` against the payee. We never mutate or store a type on the synced Lunch Money transactions.

---

## The three reports (ReportingService) — computed for a given account + period

Let `periodTxns` = the account's transactions dated in `period` (posted **and** pending), excluding income.

### 1. Total Spend — `WeeklySpend`
```
spendTxns      = periodTxns where classify(tx).kind != .payment   // charges + refunds; unmatched = Other Spend
buckets        = group spendTxns by type → SpendBucket { typeName, fundingAccountId, amount = Σ signed toBase, count }
                 (+ an "Other Spend" bucket for unmatched)
WeeklySpend.total = Σ buckets.amount
```
Refunds net within their bucket (signed). Payments never appear here.

### 2. Total Payments — `WeeklyPayments`
```
paymentTxns          = periodTxns where classify(tx).kind == .payment
WeeklyPayments.total = Σ |toBase| of paymentTxns   // shown as a positive "paid this week"
```

### 3. Payments Owed — `PaymentsOwed` (the number you actually pay)
```
pendingInPeriod   = Σ signed toBase of periodTxns that are PENDING and NOT payment
postedAfterPeriod = Σ signed toBase of post-period POSTED txns that are NOT payment
owedTotal         = currentBalance + pendingInPeriod − postedAfterPeriod

// Carve out spend covered by other accounts (Cloud 9 → Reserve):
fundedByAccount[a] = Σ signed toBase of in-period spend txns whose type.fundingAccountId == a
owedFromPrimary    = owedTotal − Σ fundedByAccount[*]
```
**Payments are excluded from every adjustment** — they simply stay baked into `currentBalance`,
where they correctly reduce what's owed. That's the whole point: a payment is not spend, so the
"cancel out the new period" logic never applies to it.

**You see** `owedFromPrimary` as the headline "Amount to Pay (from primary)", plus a line per
`fundedByAccount` (e.g. "Cloud 9 → pay $X from Reserve"). Post-period posted and the Cloud-9
carve-out are the *same kind of thing* — adjustments to the balance to isolate what primary owes —
exactly as you described.

---

## "Cloud 9 from another account" — in context

This feature **stays**, now expressed as: a `.spend` `TransactionType` with a `fundingAccountId`.

- In **Total Spend**: Cloud 9 charges show as their own bucket (so you see what you spent there).
- In **Payments Owed**: Cloud 9's in-period spend is carved out of `owedFromPrimary` and shown as
  `owedFromFunding[Reserve]` — i.e. "transfer this much from Reserve, not primary."

Future types work identically: name + payeePatterns + (optional) fundingAccountId.

---

## Migration (one-time, from current data)

We keep the two real rules and drop the rest:
- **Cloud 9**: `TransactionType(name: "Cloud 9", kind: .spend, fundingAccountId: 344059 /*Reserve*/, targetAccountId: 344066, payeePatterns: ["Cloud 9"])`
- **PNC Payment**: `TransactionType(name: "PNC Payment", kind: .payment, targetAccountId: 344066, payeePatterns: ["THANK YOU FOR YOUR PMT"])`
- **PNC Payment (Points)**: same, `targetAccountId: 344065`.
- **Delete** the two "Everything Else → Payroll" default rules (they wrongly subtracted everything in the balance-based model — Other Spend is implicit now).

Migration runs in-app (seed/convert existing `TransferRule`/`Vendor` rows into `TransactionType`)
and the result syncs to the server via the existing LWW merge. The CLI gets a
`transaction-types` command mirroring today's `transfer-rules` (list/add/delete).

---

## Code changes

**Remove**
- `Vendor`, `TransferRule`, `RuleKind` (SDK + SwiftData + DynamoDB stores + API `/api/vendors`, `/api/transfer-rules`).
- `PaydownCalculation`-as-charge-allocation, the per-source `TransferBreakdown`, the
  "Pay From Each Account" UI, and the temporary **SYNC DIAG** box.

**Add**
- `TransactionType` + `TransactionTypeKind` (SDK), SwiftData model (`isTombstoned` mirror), domain mappings.
- `TransactionClassifier` (the `classify` matcher).
- `WeeklySpend`, `WeeklyPayments`, `PaymentsOwed`, combined `WeeklyPaydownReport` (ReportingService) — the single shared calc used by **both iOS and Lambda** (DRY).
- `/api/transaction-types` (GET + PUT-merge), `TransactionTypeStore` (DynamoDB), CLI `transaction-types`.

**Keep**
- LWW + tombstone sync (now on `TransactionType`), `isTombstoned` reserved-name fix.
- Current + Last cycle selector; the daily push (body shows Amount to Pay + Total Spend).
- The shared-calc / DRY principle: iOS and Lambda call the same ReportingService functions.

---

## UI

- **Transaction Types** management screen (replaces Transfer Rules / Vendors): create a type, set
  `kind` (Spend/Payment), `fundingAccountId` (for spend), and `payeePatterns`.
- **Weekly Paydown** screen shows three clearly-labeled sections:
  1. **Amount to Pay** (Payments Owed): `owedFromPrimary` headline + per-funding-account lines + the
     adjustment breakdown (Current Balance, + Pending This Period, − Posted After Period).
  2. **Total Spend**: buckets by type (Cloud 9, …, Other Spend) + total.
  3. **Total Payments**: paid this week.

---

## Open questions / confirmations

1. **Payments Owed adjustments** — confirm payments are excluded from *both* the in-period-pending
   add and the post-period-posted subtract (they only live in `currentBalance`). ✅ assumed.
2. **Funded carve-out scope** — carve out funded types (Cloud 9) using **in-period spend** only
   (matches today's behavior), or also pending/post-period funded charges? I'll default to
   in-period; flag if you want otherwise.
3. **Refunds** — net within their type bucket and within the owed adjustments (signed). ✅ assumed.
4. **Naming** — OK with `TransactionType` / `TransactionTypeKind` / `payeePatterns` /
   `fundingAccountId` as the code-level names? These will appear throughout.
5. **One credit card scope** — types carry `targetAccountId` (per card), as today. Keep?

Once you confirm, I'll implement in phases: SDK model → shared calc + tests → server/CLI →
iOS UI + migration → deploy → verify the numbers match your hand calc → pus h.
