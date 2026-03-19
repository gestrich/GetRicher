## Relevant Skills

| Skill | Description |
|-------|-------------|
| `swift-architecture` | 4-layer architecture rules (SDKs → Services → Features → Apps), dependency rules, placement guidance |
| `swift-swiftui` | SwiftUI Model-View patterns, enum-based state, observable model conventions |

## Background

Currently GetRicher fetches transactions and accounts from Lunch Money's API on every app launch and holds them only in memory (via `TransactionsModel` and `AccountsModel`). There is no local persistence — if the network is unavailable, the app shows nothing.

Bill wants to introduce **SwiftData** as the local persistence layer with:

1. **Two model layers**: DTO structs (the existing `LunchMoneyTransaction`, `LunchMoneyPlaidAccount` in LunchMoneySDK) stay as-is for API decoding. New `@Model` classes in a services-layer target become the app's domain/persistence models.
2. **Sync logic**: When we fetch from Lunch Money, we diff against local SwiftData records and only insert/update/delete what actually changed. The `updatedAt` field on transactions is the natural change-detection key.
3. **Sync triggers**: On app launch, on foreground entry, and on pull-to-refresh.
4. **UI reads from SwiftData**: Views use `@Query` or model-layer queries against SwiftData instead of holding arrays in `@Observable` models.

### Architecture placement

| Concern | Layer | Target |
|---------|-------|--------|
| Lunch Money API DTOs + client | SDK | `LunchMoneySDK` (unchanged) |
| SwiftData `@Model` classes | Services | New `PersistenceService` target |
| Sync logic (diff + upsert) | Services | New `SyncService` target (depends on `LunchMoneySDK`, `PersistenceService`, `KeychainSDK`) |
| Use cases (trigger sync, query data) | Features | `TransactionFeature` (updated) |
| SwiftUI views + models | Apps | `Finance` app target (updated) |

The existing `CoreService` models (`Transaction`, `PlaidAccount`) will be replaced by SwiftData models from `PersistenceService`. `CoreService` can be retired or repurposed for shared utilities (like `CurrencyFormatter`, `VendorSpending`).

## Phases

## - [ ] Phase 1: Create SwiftData models in PersistenceService

**Skills to read**: `swift-architecture`

Create a new `PersistenceService` target in `FinancePackage` at `Sources/services/PersistenceService/`.

**SwiftData models to create:**

- `Transaction` — `@Model` class with all transaction fields. Uses `lunchMoneyId: Int` as the external identifier (unique).
- `PlaidAccount` — `@Model` class with all account fields. Uses `lunchMoneyId: Int` as the external identifier (unique).
- `Tag` — `@Model` class for tags (id + name), with a many-to-many relationship to `Transaction`.

**Naming convention:**
- SwiftData models use plain names: `Transaction`, `PlaidAccount`, `Tag`
- Lunch Money API DTOs get `DTO` suffix: `TransactionDTO`, `PlaidAccountDTO`, `TagDTO`

**Key decisions:**
- Use `@Attribute(.unique)` on `lunchMoneyId` for upsert support
- Store `updatedAt` as `String` (matching the API format) for easy change detection
- Keep all fields optional where the API returns optional
- Add `Package.swift` target entry with no dependencies (pure SwiftData models)

## - [ ] Phase 2: Create SyncService with diff-based sync logic

**Skills to read**: `swift-architecture`

Create a new `SyncService` target at `Sources/services/SyncService/` that depends on `LunchMoneySDK`, `PersistenceService`, and `KeychainSDK`.

**Components:**

- `TransactionSyncService` — Takes a `ModelContext`, fetches transactions from Lunch Money, then:
  - For each fetched DTO, look up by `lunchMoneyId`
  - If not found → insert new `SDTransaction`
  - If found and `updatedAt` differs → update all fields
  - If a local record's `lunchMoneyId` is not in the fetched set → delete it (for the queried date range)
  - Returns a `SyncResult` (inserted: Int, updated: Int, deleted: Int)

- `AccountSyncService` — Same pattern for `SDPlaidAccount`

- `SyncCoordinator` — Orchestrates syncing both transactions and accounts. Tracks last sync time. Exposes a simple `sync(context:startDate:endDate:)` method.

**Mapping**: Simple static functions that convert `LunchMoneyTransaction` → `SDTransaction` field assignments (similar to current `TransactionMapper` but writing into `@Model` objects).

## - [ ] Phase 3: Update TransactionFeature use cases

**Skills to read**: `swift-architecture`

Update `TransactionFeature` to depend on `PersistenceService` and `SyncService` instead of directly returning DTOs.

**Changes:**

- `FetchTransactionsUseCase` → becomes `SyncAndQueryTransactionsUseCase`:
  - Triggers sync via `SyncCoordinator`
  - Then queries SwiftData for the requested date range / account filter
  - Returns `[SDTransaction]` from the local store
  
- `FetchAccountsUseCase` → becomes `SyncAndQueryAccountsUseCase`:
  - Triggers account sync
  - Returns `[SDPlaidAccount]` from SwiftData

- `AggregateVendorSpendingUseCase` — Update to work with `SDTransaction` instead of `Transaction`

- Remove or deprecate `TransactionMapper` (mapping now lives in `SyncService`)

## - [ ] Phase 4: Update App layer (models, views, ModelContainer)

**Skills to read**: `swift-swiftui`

**App entry point (`FinanceApp.swift`):**
- Create a `ModelContainer` for `SDTransaction`, `SDPlaidAccount`, `SDTag`
- Attach via `.modelContainer()` modifier
- Pass `ModelContext` to models/use cases that need it

**Observable models:**
- `TransactionsModel` — Instead of holding `[Transaction]` in state, trigger sync and let views query SwiftData via `@Query`. The model becomes thinner: it manages sync state (syncing/synced/error) rather than holding data.
- `AccountsModel` — Same pattern: triggers sync, views use `@Query` for account list.

**Views:**
- `TransactionsListView` — Use `@Query` with sort/filter descriptors for transactions
- `ContentView`, `CombinedView` — Adapt to new model types
- `TransactionDetailView` — Accept `SDTransaction` instead of `Transaction`
- `VendorSpendingView` — Adapt to `SDTransaction`
- Pull-to-refresh triggers sync via the model
- `onAppear` / `scenePhase` changes trigger sync

**Demo mode:** Create an in-memory `ModelContainer` pre-seeded with demo data (replacing `DemoLunchMoneyClient` pattern).

## - [ ] Phase 5: Retire CoreService models and clean up

**Skills to read**: `swift-architecture`

- Remove `Transaction` and `PlaidAccount` structs from `CoreService` (replaced by SwiftData models)
- Keep `CurrencyFormatter` and `VendorSpending` in `CoreService` (or move to `PersistenceService` if they only operate on SwiftData types)
- Remove `TransactionMapper` from `TransactionFeature`
- Update `Package.swift` — remove `CoreService` dependency from targets that no longer need it
- Clean up any dead imports

## - [ ] Phase 6: Validation

**Skills to read**: `swift-architecture`, `swift-swiftui`

- **Build**: Verify `swift build` succeeds for the package and `xcodebuild` for the app
- **Unit tests**: Add tests for sync logic in `SyncService`:
  - Sync inserts new records when local store is empty
  - Sync updates records when `updatedAt` changes
  - Sync deletes records not in the fetched set
  - Sync is a no-op when nothing changed
- **UI tests**: Run existing UI tests to verify no visual regressions
- **Manual smoke test**: Launch app in demo mode, verify data appears, verify pull-to-refresh works
