## Relevant Skills

| Skill | Description |
|-------|-------------|
| `/swift-architecture` | Code placement, layer definitions, dependency rules, feature creation guidance |
| `/swift-swiftui` | SwiftUI view patterns, observable models, dependency injection, state management |
| `swift-testing` | Test style guide and conventions for Swift Testing framework |

## Background

Currently the iOS app syncs financial data (accounts + transactions) **directly** with the Lunch Money API via `SyncCoordinator` in `SyncService`, using the token from `KeychainSDK`. The Lambda is a pass-through: it fetches from Lunch Money on every API request rather than serving cached data.

The goal is to make Lambda the **sole source of truth** for financial data:

- Lambda polls Lunch Money hourly and persists all financial data in DynamoDB
- All reads (from iOS and CLI) go through Lambda — Lunch Money is never called from the client
- iOS becomes a dumb client: it caches in SwiftData but sources everything from Lambda
- A Swift CLI provides full feature parity with the iOS app and serves as the primary verification tool
- Admin endpoints expose user management, report management, error inspection, and per-user LM token management

The existing LM token is currently a single server-side AWS secret. Under the new design, each user's LM token is stored per-user in DynamoDB (submitted at registration). The admin can update any user's token.

**Key existing pieces to build on:**
- `ClientService/APIClient.swift` — already wraps remote + local Lambda calls; iOS and CLI should both use this
- `NotificationService/DynamoDBDeviceTokenStore.swift` — pattern for DynamoDB stores
- `LambdaApp/GetRicherLambda.swift` — all routing lives here; it handles both `.scheduled` and `.apiGateway` events
- `CLIApp/` — has a single `invoke` command; needs full subcommand expansion
- `SyncService/SyncCoordinator.swift` — currently calls `LunchMoneyClient` directly; will be replaced with Lambda-backed sync
- CDK already has EventBridge schedule wired to Lambda (via `MonitoringConstruct`)

## Phases

## - [x] Phase 1: Per-User LM Token + DynamoDB Financial Data Layer

**Skills used**: none (swift-architecture skill not locally available; conventions derived from reading existing store files directly)
**Principles applied**: Added `lunchMoneyToken: String?` to `UserAccount` and updated `DynamoDBUserStore` to conditionally include the field in create/find/update. Added `Codable` conformance to `Account`, `Transaction`, and `Tag` to enable JSON-payload serialization in the new DynamoDB stores. Added `AccountStoreProtocol`/`TransactionStoreProtocol` with DynamoDB and Logging stub implementations following the exact pattern of `ReviewItemStoreProtocol`/`DynamoDBReviewItemStore`. Transaction records use an `expressionAttributeNames` alias for the reserved word `date`. New stores wired into both startup branches of `GetRicherLambda` with the logging/production pattern.

**Skills to read**: `/swift-architecture`

Store each user's Lunch Money API token in DynamoDB alongside their user record, and add DynamoDB-backed store protocols for accounts and transactions.

**Tasks:**
- Update `UserAccount` model in `FinanceCoreSDK` to include an optional `lunchMoneyToken: String?` field
- Update `DynamoDBUserStore` to persist and retrieve `lunchMoneyToken`
- Add `UserStoreProtocol` method `update(lunchMoneyToken:forUsername:)` with DynamoDB implementation
- Update `POST /api/users/register` to accept and store `lunchMoneyToken` in the request body
- Add new protocol `AccountStoreProtocol` in an appropriate service (e.g., `NotificationService` or a new `DataService`) with methods:
  - `store(_ accounts: [Account], userId: String)` 
  - `fetchAll(userId: String) -> [Account]`
- Add `DynamoDBAccountStore` implementing `AccountStoreProtocol`
- Add new protocol `TransactionStoreProtocol` with methods:
  - `store(_ transactions: [Transaction], userId: String)`
  - `fetch(userId: String, startDate: String, endDate: String) -> [Transaction]`
- Add `DynamoDBTransactionStore` implementing `TransactionStoreProtocol`
- Add logging stub implementations (`LoggingAccountStore`, `LoggingTransactionStore`) for local dev mode
- Wire new stores into `LambdaApp` startup (both env-token and AWS branches)

**DynamoDB record shape:**
- Accounts: `PK = userId, SK = "account#<lunchMoneyId>"`, `recordType = "account"`
- Transactions: `PK = userId, SK = "transaction#<id>"`, `recordType = "transaction"`, `date` attribute for range queries

## - [x] Phase 2: Lambda Hourly Data Fetch

**Skills used**: none (swift-architecture skill not locally available; conventions derived from reading existing store and Lambda files directly)
**Principles applied**: Added `fetchAll()` to `UserStoreProtocol` with DynamoDB scan implementation and logging stub. Added `handleHourlyDataFetch` as a non-throwing async function that iterates all users, skips those without an LM token, syncs accounts and transactions (90-day rolling window, paginated), and logs per-user success/failure without aborting the job. The `.scheduled` branch calls `handleHourlyDataFetch` first then falls through to the existing report generation. CDK dev schedule updated from `cron(0 6 * * ? *)` to `rate(1 hour)`.

**Skills to read**: `/swift-architecture`

Add a scheduled Lambda handler that polls Lunch Money for every registered user and writes accounts and transactions to DynamoDB.

**Tasks:**
- In `GetRicherLambda.handleScheduled(...)`, iterate over all users returned by `UserStoreProtocol.fetchAll()`
- For each user that has a `lunchMoneyToken`, call `LunchMoneyClient.fetchPlaidAccounts` and `fetchTransactions` for a rolling 90-day window
- Write results to `AccountStoreProtocol` and `TransactionStoreProtocol`
- Log per-user success/failure; continue to next user on error (don't abort the whole job)
- Keep existing scheduled report-generation logic intact (or move it to a separate branch of the scheduled handler)
- CDK: confirm EventBridge schedule is set to `rate(1 hour)` in `MonitoringConstruct` (update if it's currently daily)
- Update Lambda environment to include any new required env vars (none expected — stores already receive `awsClient`)

## - [x] Phase 3: Lambda API Endpoints for Financial Data

**Skills used**: none (swift-architecture skill not locally available; conventions derived from reading existing Lambda handler and store files directly)
**Principles applied**: Added `handleGetAccounts` (GET /api/accounts) and `handleGetTransactions` (GET /api/transactions) using query-param auth (username/password), and `handleRefresh` (POST /api/refresh) using body auth — all following the existing if-else routing pattern in `handleAPIGateway`. Added `generatePaydownDataFromDynamoDB` to read accounts/transactions from DynamoDB stores and updated `handleSendMyReport` to use it instead of calling `LunchMoneyClient` directly. `handleGenerateReport` retains LM calls since it is a system-level operation with no per-user context. `RefreshRequest` added alongside existing private request types.

**Skills to read**: `/swift-architecture`

Add Lambda API endpoints that serve cached financial data from DynamoDB, so clients never need to call Lunch Money directly.

**New endpoints:**
- `GET /api/accounts` — requires `username`/`password` in query params or Basic auth header; returns user's cached accounts from DynamoDB
- `GET /api/transactions` — requires auth + `startDate`/`endDate` query params; returns user's cached transactions from DynamoDB
- `POST /api/refresh` — triggers an immediate on-demand fetch for the authenticated user (calls LM, stores to DynamoDB, returns updated data)

**Tasks:**
- Add handler methods `handleGetAccounts`, `handleGetTransactions`, `handleRefresh` in `GetRicherLambda`
- Add authentication helper that validates username/password via `UserStoreProtocol.find(username:)` + hash comparison (reuse existing pattern from `handleSendMyReport`)
- Route new paths in `handleAPIGateway`
- Add `Encodable` response types for accounts and transactions
- Update `handleGenerateReport` and `handleSendMyReport` to read transactions/accounts from DynamoDB instead of calling `LunchMoneyClient` directly

## - [ ] Phase 4: iOS Dumb Client

**Skills to read**: `/swift-architecture`, `/swift-swiftui`

Replace `SyncService`'s direct Lunch Money calls with Lambda API calls. iOS retains SwiftData caching but sources all data from Lambda.

**Tasks:**
- Add methods to `APIClient` (or a new `FinanceAPIClient` wrapper): `fetchAccounts(username:password:)`, `fetchTransactions(username:password:startDate:endDate:)`, `triggerRefresh(username:password:)`
- Rewrite `SyncCoordinator` to call these Lambda endpoints instead of `LunchMoneyClient`:
  - Remove dependency on `LunchMoneySDK` from `SyncService`
  - Remove dependency on `KeychainSDK` token retrieval (username/password come from `KeychainSDK` or a credential store)
  - `AccountSyncService` and `TransactionSyncService` still write to SwiftData — only the source changes
- Remove `LunchMoneySDK` from `SyncService`'s dependencies in `Package.swift`
- Update iOS credential storage: iOS Keychain should store `username` + `password` (for Lambda auth), not the raw LM token. The LM token is no longer needed on-device.
- Update `SettingsModel` / `SettingsView`: replace LM token input with username/password fields (if not already done in prior phases)
- Update `DemoClients.swift` to provide demo/stub data via Lambda-shaped responses

## - [ ] Phase 5: CLI Feature Parity

**Skills to read**: `/swift-architecture`

Expand `CLIApp` from a single `invoke` command to a full-featured CLI that mirrors iOS app capabilities, using the same `ClientService` / `APIClient`.

**Subcommands to add:**

| Subcommand | Description |
|---|---|
| `accounts` | Fetch and print cached accounts for a user |
| `transactions` | Fetch transactions for a date range |
| `refresh` | Trigger on-demand LM data fetch for a user |
| `report` | Generate and print a paydown report |
| `send-report` | Send push notification report to a user's devices |
| `review-items` | List pending review items |
| `resolve-item` | Resolve a review item |

**Tasks:**
- Add a `Commands/` directory structure in `CLIApp`
- Each subcommand accepts `--username`, `--password`, `--base-url` (defaulting to the production API Gateway URL from an env var `GETRICHER_API_URL`)
- Share a `CLIConfiguration` struct for common options (base URL, credentials)
- All subcommands use `APIClient(baseURL:)` in remote mode — same path as iOS
- Remove the old `invoke` command or keep it alongside as a dev/debug utility
- Update `Package.swift` if new dependencies are needed (none expected; `ArgumentParser` already included)

## - [ ] Phase 6: Admin Endpoints + iOS Admin UI

**Skills to read**: `/swift-architecture`, `/swift-swiftui`

Add admin-only Lambda endpoints for system management and a corresponding admin section in the iOS Settings screen.

**Admin authentication:** Add a separate admin credential (admin username stored in Secrets Manager or env var, password hashed). Admin endpoints validate against this credential.

**Lambda admin endpoints:**
- `GET /api/admin/users` — list all registered users (username, createdAt, has LM token)
- `DELETE /api/admin/users/:username` — delete a user and their data (tokens, transactions, accounts)
- `GET /api/admin/reports` — list all review items across all users
- `DELETE /api/admin/reports/:id` — delete a specific review item
- `PUT /api/admin/users/:username/lm-token` — update a user's Lunch Money token in DynamoDB
- `GET /api/admin/errors` — return recent Lambda CloudWatch errors (or a stored error log in DynamoDB)

**iOS admin UI:**
- Add an "Admin" section in `SettingsView` (shown only when admin credentials are stored in Keychain)
- Views: `AdminUsersView` (list/delete users), `AdminReportsView` (list/delete reports), `AdminErrorsView`
- Use `APIClient` to call admin endpoints with admin credentials

**CLI admin subcommands:**
- `admin list-users`, `admin delete-user`, `admin list-reports`, `admin delete-report`, `admin update-lm-token`, `admin errors`

## - [ ] Phase 7: Debug Skill + Documentation

**Skills to read**: none required

Create a `.claude/skills/` skill file for fetching real Lambda data during debugging sessions, and update project docs to reference it.

**Tasks:**
- Create `.claude/skills/` directory
- Create `.claude/skills/fetch-lambda-data.md` — a skill/guide describing:
  - How to authenticate against the production Lambda (base URL from `GETRICHER_API_URL`, credentials from environment)
  - `curl` examples for each key endpoint (`/api/accounts`, `/api/transactions`, `/api/review-items`, `/api/admin/users`)
  - How to run the CLI locally against production: `swift run get-richer accounts --base-url $GETRICHER_API_URL --username ... --password ...`
  - How to trigger a manual refresh and verify data in DynamoDB
  - Common debugging patterns (check errors endpoint, inspect DynamoDB via CLI)
- Update `CLAUDE.md` to reference this skill: add it to the Architecture Skills table
- Update `README.md` to document the CLI tool and the Lambda-first data flow

## - [ ] Phase 8: Validation

**Skills to read**: `swift-testing`

Verify the end-to-end flow using the CLI as the primary verification tool, plus existing and new automated tests.

**Automated tests:**
- Add unit tests for `DynamoDBAccountStore` and `DynamoDBTransactionStore` (using logging stubs, since real DynamoDB requires AWS)
- Add unit tests for the new Lambda route handlers (inject stub stores, assert response shape)
- Run existing `ReportingServiceTests` and `LunchMoneySDKTests` — confirm they still pass

**CLI end-to-end verification (against dev environment):**
```bash
# 1. Register a test user with LM token
swift run get-richer register --username testuser --password secret --lm-token $LM_TOKEN

# 2. Trigger an immediate data refresh
swift run get-richer refresh --username testuser --password secret

# 3. Verify accounts returned from Lambda (not LM directly)
swift run get-richer accounts --username testuser --password secret

# 4. Fetch transactions for a date range
swift run get-richer transactions --username testuser --password secret --start 2026-04-01 --end 2026-05-01

# 5. Generate and review report
swift run get-richer report --username testuser --password secret

# 6. Admin: list users
swift run get-richer admin list-users --admin-password $ADMIN_PASSWORD
```

**UI tests:**
- Run existing UI tests — confirm no regressions from iOS sync changes
- Add a UI test for any new admin screen(s) in Settings

**Success criteria:**
- iOS app displays correct account balances and transactions without ever calling `lunchmoney.app` directly (verify via network proxy or removing LM token from Keychain)
- CLI produces the same report output as the iOS app
- Lambda DynamoDB contains fresh records after each hourly tick
- Admin endpoints correctly manage users and reports
