# Lambda Reporting & Modeling Split

## Relevant Skills

| Skill | Description |
|-------|-------------|
| `swift-app-architecture:swift-architecture` | 4-layer Swift architecture (Apps/Features/Services/SDKs) — layer responsibilities, dependency rules, placement, code style. |
| `swift-app-architecture:swift-swiftui` | SwiftUI Model-View patterns — observable models, model composition, dependency injection, view state vs model state. |
| `swift-testing` | Swift Testing style guide and conventions. |

## Background

GetRicher is currently an iOS/macOS-only app written in Swift + SwiftUI + SwiftData, integrating with the [Lunch Money](https://lunchmoney.app/) API. The existing modular layout in `FinancePackage` already has a clean SDKs/Services/Features layering (`LunchMoneySDK`, `PersistenceService`, `SyncService`, `LogsFeature`, etc.), which is a good starting point.

Bill wants to expand this into a richer system that includes **scheduled Swift Lambdas on AWS** that:

- Pull balance/transaction data from Lunch Money on a schedule.
- Send push notifications to the iOS app (e.g., low-balance alerts).
- Generate weekly spending reports (Shopping / Miscellaneous / Bills), Spending Goal progress, Savings Goal progress, and Fun Account balances.
- Optionally include Autopay handling.
- Create review/approval items the user can act on from the iOS app.

The core challenge: **SwiftData is not available on Linux**, but we want Linux Lambdas to keep AWS costs low. The plan is therefore to split the codebase so that:

- **Pure-Swift** layers (Lunch Money API client, domain models, report/derivation algorithms) become Linux-buildable and have no SwiftData / SwiftUI dependency.
- **SwiftData** is demoted to a *cache + reactive view layer* that wraps the pure models, used only by the iOS/macOS app.
- The Lambda app(s) live **in this same repo** as new SPM targets in `FinancePackage`, sharing the pure modules with the iOS app.

Two existing repos are reference baselines (read-only — port concepts, do not depend on them as packages):

- **`/Users/bill/Developer/work/swift/swift-lambda-sample`** — reference for `swift-aws-lambda-runtime` setup, Soto AWS clients, multi-target Package.swift with `LambdaApp` / `CLIApp` executables sharing a `ClientService`. Mirror this layout pattern.
- **`/Users/bill/Developer/personal/AIDevTools`** — reference for the GitHub Actions workflow layout (`.github/workflows/`, `scripts/`), and critically, the **platform compilation pattern** for `Package.swift` (see below).

### Platform compilation pattern (from AIDevTools)

Because `FinancePackage` must build on both Apple platforms (iOS/macOS app) and Linux (Lambda), whole targets must be compiled in or out at the **package level** — never by sprinkling `#if` inside source files.

`AIDevTools/Package.swift` demonstrates two mechanisms to use:

1. **Wholesale target/product exclusion** — wrap entire blocks of Apple-only targets, products, and their dependencies in `#if os(macOS)` (or `#if !os(Linux)`) at the top of `Package.swift`. On Linux these blocks are never evaluated.

   ```swift
   #if os(macOS) || os(iOS)
   targets.append(contentsOf: [
       // PersistenceService, SwiftUI feature targets, CLIApp, etc.
   ])
   products.append(contentsOf: [ ... ])
   #endif
   ```

2. **Conditional single dependency** — use `.when(platforms:)` on an individual product dependency when only one dep within an otherwise cross-platform target is platform-specific:

   ```swift
   .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux]))
   ```

Apply rule: if a target imports `SwiftData`, `SwiftUI`, `UIKit`, or `AppKit` it is Apple-only and must live inside a `#if os(macOS) || os(iOS)` block. Pure targets (`FinanceCoreSDK`, `LunchMoneySDK`, `ReportingService`, `LambdaApp`) stay outside any conditional and build everywhere.

Some duplication is expected and acceptable: Lunch Money entities (Transaction, Account, Category, etc.) will exist as plain Swift structs in the pure layer, and the SwiftData-backed `@Model` types in the iOS layer will marshal to/from those structs. This is a clean boundary.

## Phases

## - [ ] Phase 1: AWS CDK + Swift Lambda scaffold

See standalone plan: [`2026-05-09-a-aws-cdk-swift-lambda-scaffold.md`](2026-05-09-a-aws-cdk-swift-lambda-scaffold.md)

This phase is complete when GitHub Actions can deploy the Lambda to AWS and a `curl` to the API Gateway URL returns a hello-world response. No GetRicher domain logic is required.

## - [ ] Phase 2: Inventory & boundary mapping

**Skills to read**: `swift-app-architecture:swift-architecture`

Audit the current `FinancePackage` and `Finance/` app target to classify every type/service into one of:

- **Pure (Linux-safe)**: Lunch Money DTOs, API client, report-derivation algorithms, domain logic in `LunchMoneySDK` and most of `SyncService`.
- **SwiftData-bound**: types that import `SwiftData`, use `@Model`, `ModelContext`, `@Query`, etc. Currently in `PersistenceService` and parts of `SyncService` / app-level models.
- **SwiftUI-bound**: views and `@Observable` view models in `Finance/` and `LogsFeature`.

Produce a short inventory table inside this doc (append a section) listing each file/type and its target classification, plus the marshaling boundary (which SwiftData type maps to which pure struct). This becomes the migration checklist for Phase 3.

No code changes in this phase — just the inventory.

## - [ ] Phase 3: Extract pure domain & API layer (Linux-safe)

**Skills to read**: `swift-app-architecture:swift-architecture`

Restructure `FinancePackage` so the pure layer compiles on Linux:

- Ensure `LunchMoneySDK` has zero SwiftData / SwiftUI / Foundation-iOS dependencies. Move any `@Model` types out.
- Introduce a new SDK or service target — e.g. **`FinanceCoreSDK`** (or `DomainModels`) — containing plain Swift structs for Transaction, Account, Category, Tag, TransferRule, Vendor, VendorSpending. These are the canonical models.
- Introduce **`ReportingService`** (pure) that owns the derivation algorithms (weekly spending breakdown, spending/savings goal progress, low-balance check, fun-account snapshot). Inputs: `[Transaction]`, `[Account]`, etc. from `FinanceCoreSDK`. No SwiftData.
- Apply the platform compilation pattern: wrap `PersistenceService` and any other Apple-only targets in `#if os(macOS) || os(iOS)` blocks if not already done in Phase 1.
- Update existing `PersistenceService` / SwiftData `@Model` types to *contain* or *map to* the new pure structs rather than being the source of truth. The `@Model` types stay in a SwiftData-only target (`PersistenceService`) and gain `init(from: PureStruct)` / `toDomain() -> PureStruct` methods.
- Verify `swift build --target FinanceCoreSDK` succeeds on macOS; Linux CI (from Phase 1) confirms it stays clean there too.

## - [ ] Phase 4: Refactor app to use pure layer through SwiftData cache

**Skills to read**: `swift-app-architecture:swift-swiftui`, `swift-app-architecture:swift-architecture`

Rewire the iOS/macOS app so SwiftData is purely a cache + reactive store:

- `SyncService` fetches via `LunchMoneySDK` → returns pure `[Transaction]` etc. → writes into SwiftData via `PersistenceService`.
- View models (`TransactionsModel`, `AccountsModel`, `WeeklyPaydownModel`, `VendorSpending`, etc.) consume either:
  - SwiftData `@Query` results for reactive list views (UI), or
  - Pure `ReportingService` outputs for derived data (charts, weekly summaries).
- All algorithm logic that currently lives in app-level view models or SwiftData-backed services moves into `ReportingService`.
- App still runs end-to-end identically from the user's perspective; this phase is a structural refactor, not a behavior change.

## - [ ] Phase 5: Wire Lambda to FinanceCoreSDK + ReportingService

**Skills to read**: `swift-app-architecture:swift-architecture`

Connect the deployed scaffold Lambda to the real domain layer:

- Add `FinanceCoreSDK`, `LunchMoneySDK`, and `ReportingService` as dependencies of `LambdaApp`.
- Replace the hello-world stub with a real handler that fetches data via `LunchMoneySDK` and runs a simple derivation via `ReportingService` (e.g., a balance snapshot).
- Add **`SecretsService`**: on Lambda reads the Lunch Money API token from AWS Secrets Manager (Soto); in CLIApp reads from an environment variable or local `.env` file — replaces the iOS `KeychainSDK` for server-side use.
- Update `ConfigurationService` to load secrets via `SecretsService`.
- Verify via CLIApp locally, then deploy and hit the real endpoint.

## - [ ] Phase 6: Push notifications + device-token storage

**Skills to read**: `swift-app-architecture:swift-architecture`, `swift-app-architecture:swift-swiftui`

Wire up the notification path end-to-end:

- iOS app: register for remote notifications, capture APNs device token, send to a backing store (decide: simple S3 JSON, DynamoDB table, or a small API Gateway endpoint — recommend DynamoDB via Soto for simplicity).
- New service: **`NotificationService`** (pure, used by Lambda) — sends APNs pushes via AWS SNS Mobile Push *or* directly via a Swift APNs HTTP/2 client. Recommend **SNS Mobile Push** for simplicity (Soto already used).
- Stub a simple "low balance alert" Lambda handler in `LambdaApp` that reads a configured threshold, fetches balance via Lunch Money, and pushes a notification if under threshold.
- iOS app: handle inbound notification tap → deep link to the relevant view.

## - [ ] Phase 7: Scheduled reports + approval-item flow

**Skills to read**: `swift-app-architecture:swift-swiftui`, `swift-app-architecture:swift-architecture`

Build out the report features end-to-end. For each report below, the Lambda runs on EventBridge schedule, computes via `ReportingService`, persists the result as a structured "ReviewItem" record (DynamoDB), and pushes a notification linking the user to approve/dismiss it in the iOS app:

- **Weekly Spending** breakdown by category bucket: Shopping / Miscellaneous / Bills.
- **Spending Goal** progress this period.
- **Savings Goal** progress this period.
- **Fun Account Balances** snapshot.
- **Autopay** — bills that are scheduled vs. unpaid.

iOS app gains a **Review Inbox** view that lists pending `ReviewItem`s, lets the user approve/dismiss/snooze, and writes the result back. This is the "creates an item I can approve/review" piece from the brainstorm.

EventBridge schedule + Lambda IAM is provisioned by extending the CDK stack (`cdk/lib/swift-lambda-stack.ts`) with an EventBridge rule and appropriate Lambda IAM permissions.

## - [ ] Phase 8: Validation

**Skills to read**: `swift-testing`

Layered validation, preferring automated:

- **Unit tests** in a new `ReportingServiceTests` target covering each report derivation against fixture transactions (deterministic — no network).
- **Unit tests** for `LunchMoneySDK` decoding of recorded API responses.
- **Linux CI**: the GitHub Actions test workflow runs `swift test` on Ubuntu and passes. This is the load-bearing check that the pure layer truly is Linux-safe.
- **Lambda local invocation**: run `CLIApp` against real Lunch Money + a sandbox AWS account (Secrets Manager + DynamoDB + SNS Mobile Push) end-to-end; verify a push lands on a test device.
- **iOS UI tests**: existing `GetRicherUITests` continue to pass; add a new test for the Review Inbox screen with a screenshot per the project's UI-test convention (see `CLAUDE.md`).
- **Manual smoke**: push to `main`, let GitHub Actions deploy, verify the EventBridge-triggered run produces a notification + `ReviewItem`, confirm the iOS app surfaces it.
