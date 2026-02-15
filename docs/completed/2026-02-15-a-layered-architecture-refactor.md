# Layered Architecture Refactor

## Relevant Skills

| Skill | Description |
|-------|-------------|
| `swift-architecture` | 4-layer architecture (Apps, Features, Services, SDKs), dependency rules, placement guidance |
| `swift-swiftui` | SwiftUI Model-View patterns, enum-based state, model composition, dependency injection |

## Background

The Finance app is a macOS SwiftUI app that talks to the [Lunch Money API](https://lunchmoney.dev) to display transactions, account balances, and vendor spending charts. It currently lives in a single Xcode project target with all code in one flat `Finance/` folder (~1,415 lines across 13 files).

### Current Structure

```
Finance/
├── FinanceApp.swift          # @main App entry point
├── ContentView.swift         # Root view (just wraps CombinedView)
├── CombinedView.swift        # Main tabbed view with charts + transactions (262 lines)
├── TransactionsListView.swift # Transaction list view
├── TransactionDetailView.swift # Transaction detail view
├── VendorSpendingView.swift  # Vendor spending chart view
├── SettingsView.swift        # API token settings
├── LunchMoneyService.swift   # @Observable class: API calls + state (133 lines)
├── KeychainService.swift     # Keychain wrapper (singleton)
├── Transaction.swift         # Transaction model + response types
├── PlaidAccount.swift        # PlaidAccount model + response types
├── VendorSpending.swift      # Vendor spending aggregation logic
├── CurrencyFormatter.swift   # Currency formatting utility
```

### Architecture Violations

1. **`LunchMoneyService` mixes all layers** — It's `@Observable` (Apps concern), makes HTTP requests (SDK concern), manages pagination state, and orchestrates multi-step operations (Features concern). It's a god object.
2. **No separation between API client and business logic** — Raw HTTP calls, JSON decoding, and UI state management are all in one class.
3. **Singleton pattern** — `KeychainService.shared` uses a singleton instead of dependency injection.
4. **Views create their own state** — `TransactionsListView` and `VendorSpendingView` each create `@State private var service = LunchMoneyService()`, meaning duplicate instances and no shared state.
5. **Business logic in views** — `CombinedView` contains date filtering logic, transaction aggregation, and chart data computation.
6. **No use cases** — There's no Features layer; all orchestration happens in views or the service.

### Target Structure (Strategy: Targets in a Single Local Package)

```
Finance/                          # Xcode project (app target depends on local package)
FinancePackage/
├── Package.swift
└── Sources/
    ├── apps/
    │   └── FinanceMacApp/        # @Observable models, wired in FinanceApp
    ├── features/
    │   └── TransactionFeature/   # Use cases for fetching/filtering/aggregating
    ├── services/
    │   └── CoreService/          # Shared models (Transaction, PlaidAccount, VendorSpending)
    └── sdks/
        ├── LunchMoneySDK/        # Stateless HTTP client for Lunch Money API
        └── KeychainSDK/          # Stateless keychain wrapper
```

## Phases

## - [ ] Phase 1: Create local package with SDKs layer

**Skills to read**: `swift-architecture`

Extract stateless, reusable code into SDK targets:

- Create `FinancePackage/Package.swift` with initial targets
- **LunchMoneySDK**: Extract the HTTP client from `LunchMoneyService` into a stateless `Sendable` struct `LunchMoneyClient`. Methods:
  - `fetchTransactions(token:accountId:startDate:endDate:limit:offset:) async throws -> TransactionsResponse`
  - `fetchPlaidAccounts(token:) async throws -> PlaidAccountsResponse`
  - Move `TransactionsResponse` and `PlaidAccountsResponse` here (API response types belong with the client)
- **KeychainSDK**: Extract `KeychainService` into a stateless `Sendable` struct `KeychainClient` (no singleton). Methods:
  - `saveAPIToken(_:) throws`
  - `getAPIToken() -> String?`
  - `deleteAPIToken() throws`
- Verify the Xcode project can depend on the local package
- All existing app behavior should remain unchanged

## - [ ] Phase 2: Create Services layer with shared models

**Skills to read**: `swift-architecture`

Extract shared domain models into a service target:

- **CoreService**: Move domain models here:
  - `Transaction` (the domain model, not the API response)
  - `PlaidAccount` (domain model)
  - `VendorSpending` (including the `aggregate(from:)` logic)
  - `CurrencyFormatter`
- Update SDK targets to NOT depend on CoreService (SDKs should be independent; if needed, SDKs define their own API response types and Features map them to domain models)
- Update dependency graph in `Package.swift`

## - [ ] Phase 3: Create Features layer with use cases

**Skills to read**: `swift-architecture`

Create use cases that orchestrate SDK calls and return domain state:

- **TransactionFeature**:
  - `FetchTransactionsUseCase` — coordinates LunchMoneyClient + KeychainClient to fetch transactions with pagination, maps API responses to domain `Transaction` models
  - `FetchAccountsUseCase` — fetches Plaid accounts
  - `AggregateVendorSpendingUseCase` — takes transactions, filters by date/account, returns `[VendorSpending]`
- Use cases are `Sendable` structs, not `@Observable`
- Use cases accept dependencies (SDK clients) via init, not singletons

## - [ ] Phase 4: Create Apps layer models

**Skills to read**: `swift-swiftui`

Create `@Observable` models that consume use cases and drive the UI:

- **FinanceMacApp** target (or kept in the Xcode app target):
  - `TransactionsModel` — `@Observable @MainActor` class that uses `FetchTransactionsUseCase`, owns loading/error/pagination state as an enum:
    ```swift
    enum State {
        case idle
        case loading
        case loaded(transactions: [Transaction], hasMore: Bool)
        case error(String)
    }
    ```
  - `AccountsModel` — manages Plaid accounts state
  - `VendorSpendingModel` — uses aggregation use case, owns date filter and account filter state
  - `SettingsModel` — manages API token save/load via KeychainClient
- Models are initialized with use cases (dependency injection), not singletons
- Root model composition: a parent model or the `App` struct holds child models

## - [ ] Phase 5: Refactor views to use models

**Skills to read**: `swift-swiftui`

Update SwiftUI views to consume the new `@Observable` models:

- Remove `@State private var service = LunchMoneyService()` from views
- Inject models via `@Environment` or pass as parameters
- Move date filtering logic out of `CombinedView` into `VendorSpendingModel`
- Move chart data computation out of views into models
- Views should only bind to model state and call model methods
- Delete `LunchMoneyService.swift` (fully replaced by SDKs + Features + Models)
- Delete old files that have been fully migrated

## - [ ] Phase 6: Validation

**Skills to read**: `swift-architecture`, `swift-swiftui`

- Build the project and verify no compiler errors
- Run the app and verify all features work:
  - [ ] Transactions load and paginate
  - [ ] Account filtering works
  - [ ] Vendor spending chart renders correctly
  - [ ] Date filtering (week/month/year/all) works
  - [ ] Settings view saves/loads API token
  - [ ] Transaction detail view displays correctly
- Verify architecture compliance:
  - [ ] `@Observable` only in Apps layer
  - [ ] SDKs are stateless `Sendable` structs
  - [ ] No singletons
  - [ ] Dependencies flow downward only (Apps → Features → Services → SDKs)
  - [ ] Views contain no business logic
  - [ ] Use cases orchestrate, not views or models
