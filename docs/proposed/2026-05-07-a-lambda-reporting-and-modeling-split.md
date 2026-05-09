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

## - [x] Phase 1: AWS CDK + Swift Lambda scaffold

**Skills used**: `swift-app-architecture:swift-architecture`
**Principles applied**: Copied scaffold from `swift-lambda-sample` reference repo; applied platform compilation pattern (wholesale `#if os(macOS) || os(iOS)` block exclusion in `Package.swift`) so Apple-only targets are excluded on Linux; `LambdaApp` and `ClientService` are unconditional and build everywhere. CDK stack trimmed to remove VPC/NAT/RDS; GitHub Actions `deploy_dev.yml` uses OIDC for keyless AWS auth. All four sub-phases (scaffold copy, local CLIApp invocation, CDK deploy, end-to-end validation) completed; `swift build --product LambdaApp` passes on macOS and the deployed API Gateway endpoint returns a hello-world response.

See standalone plan: [`2026-05-09-a-aws-cdk-swift-lambda-scaffold.md`](2026-05-09-a-aws-cdk-swift-lambda-scaffold.md)

This phase is complete when GitHub Actions can deploy the Lambda to AWS and a `curl` to the API Gateway URL returns a hello-world response. No GetRicher domain logic is required.

## - [x] Phase 2: Inventory & boundary mapping

**Skills used**: `swift-app-architecture:swift-architecture`
**Principles applied**: Read all targets in Package.swift and sampled every source file to classify platform safety. Confirmed that SwiftData `@Model` types are already isolated in `PersistenceService`; `LunchMoneySDK` is already import-clean. The key gap for Phase 3 is that plain-struct equivalents of the six `@Model` types do not yet exist — they must be introduced in a new `FinanceCoreSDK` (or `DomainModels`) target so Lambda and `ReportingService` can share them without pulling in SwiftData.

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

---

## Phase 2 Inventory: File Classification

### FinancePackage — SDKs Layer

| File | Target | Classification | Notes |
|------|--------|----------------|-------|
| `Sources/sdks/LoggingSDK/GetRicherLogging.swift` | LoggingSDK | **Pure** | Foundation + swift-log only |
| `Sources/sdks/LoggingSDK/FileLogHandler.swift` | LoggingSDK | **Pure** | Foundation + swift-log only |
| `Sources/sdks/LoggingSDK/LogReaderService.swift` | LoggingSDK | **Pure** | Foundation only |
| `Sources/sdks/LoggingSDK/LogFileWatcher.swift` | LoggingSDK | **Darwin-only** | `#if canImport(Darwin)` guard already present |
| `Sources/sdks/LunchMoneySDK/LunchMoneyClient.swift` | LunchMoneySDK | **Pure** | Foundation only; defines `LunchMoneyClientProtocol`, `LunchMoneyClient`, `TransactionDTO`, `PlaidAccountDTO`, `TagDTO` |
| `Sources/sdks/KeychainSDK/KeychainClient.swift` | KeychainSDK | **Apple-only** | Security framework |
| `Sources/sdks/Uniflow/UseCase.swift` | Uniflow | **Pure** | Foundation only |

### FinancePackage — Services Layer

| File | Target | Classification | Notes |
|------|--------|----------------|-------|
| `Sources/services/CoreService/CurrencyFormatter.swift` | CoreService | **Pure** | Foundation only |
| `Sources/services/PersistenceService/Transaction.swift` | PersistenceService | **SwiftData-bound** | `@Model final class Transaction` — 48 properties |
| `Sources/services/PersistenceService/Category.swift` | PersistenceService | **SwiftData-bound** | `@Model final class Category` |
| `Sources/services/PersistenceService/PlaidAccount.swift` | PersistenceService | **SwiftData-bound** | `@Model final class PlaidAccount` |
| `Sources/services/PersistenceService/Tag.swift` | PersistenceService | **SwiftData-bound** | `@Model final class Tag` |
| `Sources/services/PersistenceService/Vendor.swift` | PersistenceService | **SwiftData-bound** | `@Model final class Vendor` |
| `Sources/services/PersistenceService/TransferRule.swift` | PersistenceService | **SwiftData-bound** | `@Model final class TransferRule` |
| `Sources/services/PersistenceService/VendorSpending.swift` | PersistenceService | **Pure** | Plain `struct VendorSpending` — no SwiftData; could move to `FinanceCoreSDK` |
| `Sources/services/SyncService/SyncCoordinator.swift` | SyncService | **SwiftData-bound** | Imports SwiftData + PersistenceService |
| `Sources/services/SyncService/AccountSyncService.swift` | SyncService | **SwiftData-bound** | Imports SwiftData + PersistenceService |
| `Sources/services/SyncService/TransactionSyncService.swift` | SyncService | **SwiftData-bound** | Imports SwiftData + PersistenceService |
| `Sources/services/SyncService/SyncResult.swift` | SyncService | **Pure** | Plain `struct SyncResult` — no SwiftData |
| `Sources/services/ClientService/APIClient.swift` | ClientService | **Pure** | Conditional `FoundationNetworking` on Linux |
| `Sources/services/ClientService/APIGatewayRequestWrapper.swift` | ClientService | **Pure** | Foundation only |
| `Sources/services/ClientService/APIGatewayResponseWrapper.swift` | ClientService | **Pure** | Foundation only |

### FinancePackage — Features Layer

| File | Target | Classification | Notes |
|------|--------|----------------|-------|
| `Sources/features/LogsFeature/usecases/StreamLogsUseCase.swift` | LogsFeature | **Pure** | LoggingSDK + Uniflow only |
| `Sources/features/LogsFeature/usecases/ClearLogsUseCase.swift` | LogsFeature | **Pure** | LoggingSDK + Uniflow only |

### FinancePackage — Apps Layer

| File | Target | Classification | Notes |
|------|--------|----------------|-------|
| `Sources/apps/LambdaApp/GetRicherLambda.swift` | LambdaApp | **Pure** | AWSLambdaRuntime + Foundation; cross-platform |
| `Sources/apps/CLIApp/main.swift` | CLIApp | **Apple-only** | Wrapped in `#if os(macOS) || os(iOS)` |
| `Sources/apps/CLIApp/Commands/InvokeCommand.swift` | CLIApp | **Apple-only** | Wrapped in `#if os(macOS) || os(iOS)` |

### Finance/ — iOS/macOS App Target

| File | Classification | Notes |
|------|----------------|-------|
| `FinanceApp.swift` | **SwiftData-bound + SwiftUI-bound** | App entry point; creates `ModelContainer` |
| `ContentView.swift` | **SwiftUI-bound** | TabView shell |
| `CombinedView.swift` | **SwiftData-bound + SwiftUI-bound** | `@Query` transactions/accounts; Charts |
| `WeeklyPaydownView.swift` | **SwiftData-bound + SwiftUI-bound** | `WeeklyPaydownModel`; Charts |
| `TransactionsModel.swift` | **SwiftData-bound + SwiftUI-bound** | `@Observable`; algorithm logic that should move to `ReportingService` |
| `AccountsModel.swift` | **SwiftUI-bound** | `@Observable`; currently empty |
| `SettingsModel.swift` | **SwiftUI-bound** | `@Observable`; KeychainSDK only |
| `WeeklyPaydownModel.swift` | **SwiftData-bound + SwiftUI-bound** | `@Observable`; derivation logic should move to `ReportingService` |
| `LogsModel.swift` | **SwiftUI-bound** | `@Observable`; LoggingSDK + LogsFeature only |
| `SettingsView.swift` | **SwiftUI-bound** | |
| `LogsView.swift` | **SwiftUI-bound** | |
| `LogItem.swift` | **Pure** | Plain `struct`; no SwiftUI/SwiftData |
| `TransactionsListView.swift` | **SwiftData-bound + SwiftUI-bound** | `@Query` |
| `TransactionDetailView.swift` | **SwiftData-bound + SwiftUI-bound** | PersistenceService `@Model` types |
| `TransactionContextMenu.swift` | **SwiftData-bound + SwiftUI-bound** | |
| `CategoryListView.swift` | **SwiftData-bound + SwiftUI-bound** | `@Query` |
| `CategoryEditView.swift` | **SwiftData-bound + SwiftUI-bound** | |
| `VendorListView.swift` | **SwiftData-bound + SwiftUI-bound** | `@Query` |
| `VendorEditView.swift` | **SwiftData-bound + SwiftUI-bound** | |
| `VendorSpendingView.swift` | **SwiftData-bound + SwiftUI-bound** | Charts |
| `TransferRulesListView.swift` | **SwiftData-bound + SwiftUI-bound** | `@Query` |
| `TransferRuleEditView.swift` | **SwiftData-bound + SwiftUI-bound** | |
| `FilteredTransactionListView.swift` | **SwiftData-bound + SwiftUI-bound** | |
| `DateFilter.swift` | **SwiftUI-bound** | |
| `DemoClients.swift` | **Pure** | Implements `KeychainClientProtocol`, `LunchMoneyClientProtocol`; no SwiftData/SwiftUI |

---

### Marshaling Boundary (SwiftData → Pure Struct)

These are the `@Model` types that need plain-struct counterparts in `FinanceCoreSDK` for Phase 3:

| SwiftData `@Model` (PersistenceService) | Target pure struct (FinanceCoreSDK) | Already exists? |
|-----------------------------------------|--------------------------------------|-----------------|
| `Transaction` | `Transaction` (plain struct) | No — `TransactionDTO` in LunchMoneySDK is the API shape, not the domain model |
| `PlaidAccount` | `Account` (plain struct) | No — `PlaidAccountDTO` in LunchMoneySDK is the API shape |
| `Category` | `Category` (plain struct) | No |
| `Tag` | `Tag` (plain struct) | No — `TagDTO` in LunchMoneySDK is the API shape |
| `Vendor` | `Vendor` (plain struct) | No |
| `TransferRule` | `TransferRule` (plain struct) | No |
| `VendorSpending` | `VendorSpending` (plain struct) | **Yes** — already a plain struct in PersistenceService; move to FinanceCoreSDK |

**Note**: `LunchMoneySDK` already has `TransactionDTO`, `PlaidAccountDTO`, and `TagDTO` as API-layer DTOs. The new pure structs in `FinanceCoreSDK` will be the canonical domain models; `LunchMoneySDK` maps DTOs → domain; `PersistenceService` maps domain ↔ `@Model`.
