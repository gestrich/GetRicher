# Weekly Paydown Push Notifications & Multi-User Accounts

## Relevant Skills

| Skill | Description |
|-------|-------------|
| `swift-app-architecture:swift-architecture` | 4-layer Swift architecture — layer responsibilities, dependency rules, placement. |
| `swift-app-architecture:swift-swiftui` | SwiftUI Model-View patterns — observable models, dependency injection, view state. |

## Background

The app's Weekly Paydown view already computes the current-period paydown using domain-level types (`PaydownCalculation`, `PaydownDateRange`) in `ReportingService`. However, the transaction-filtering logic that feeds those computations lives in `WeeklyPaydownModel` — an iOS-only `@Observable` class — making it unreachable by the Lambda.

This plan achieves three things:

1. **Extract shared report logic** into `ReportingService` so the Lambda can compute the same paydown report the app displays, without duplicating logic.
2. **Add a simple user-account system** (username + password) stored in DynamoDB, so multiple users can register their devices and receive pushes.
3. **Wire daily push notifications** (5 AM UTC via EventBridge) and a "Send Report Now" option in iOS Settings for the current user only.

### Key observations from the code

- `PaydownCalculation.compute()` and `PaydownDateRange.compute()` are already pure domain functions in `FinancePackage/Sources/services/ReportingService/` — no refactor needed there.
- The filtering (`periodTransactions`, `postPeriodClearedTransactions`) is in `WeeklyPaydownModel` and must be moved to a new service function.
- `LunchMoneyClient.fetchTransactions()` already exists and can be called from the Lambda.
- `DeviceToken` currently has no `userId` field; it needs one to support "send to this user only."
- The CDK EventBridge rule currently fires weekly (Sunday 8 AM UTC); it needs to become daily at 5 AM UTC.
- Password hashing uses SHA-256 via `CryptoKit` (available on both Apple platforms and Linux in Swift 5.9+).

---

## Phases

## - [x] Phase 1: Extract `WeeklyPaydownReport` into `ReportingService`

**Skills used**: `swift-app-architecture:swift-architecture`
**Principles applied**: Added `AccountPaydownReport` and `WeeklyPaydownReport` value types to `ReportingService`. Exposed a `dateRange`-based overload of `compute()` alongside the `pivotDay+referenceDate` overload so `WeeklyPaydownModel` can support historical period selection while the Lambda uses the simpler pivot-day API. Removed `periodTransactions()` and `postPeriodClearedTransactions()` from `WeeklyPaydownModel`; inlined the equivalent filter in `WeeklyPaydownView` and delegated `calculation()` to `WeeklyPaydownReport.compute()`.

**Skills to read**: `swift-app-architecture:swift-architecture`

Add two new files to `FinancePackage/Sources/services/ReportingService/`:

**`AccountPaydownReport.swift`** — a pure value type:
```swift
public struct AccountPaydownReport: Sendable {
    public let account: Account
    public let calculation: PaydownCalculation
    public let periodStart: String
    public let periodEnd: String
}
```

**`WeeklyPaydownReport.swift`** — static factory + formatter:
```swift
public struct WeeklyPaydownReport {
    /// Computes a paydown report for every credit account.
    public static func compute(
        accounts: [Account],
        transactions: [Transaction],
        pivotDay: PivotDay,
        referenceDate: Date = Date()
    ) -> [AccountPaydownReport]

    /// Formats a short string suitable for a push notification body.
    /// e.g. "PNC Core: $1,234.56 | PNC Points: $456.78"
    public static func notificationBody(from reports: [AccountPaydownReport]) -> String
}
```

`compute()` mirrors the filtering logic currently in `WeeklyPaydownModel`:
- `periodTransactions`: `tx.plaidAccountId == account.lunchMoneyId && tx.date > range.start && tx.date <= range.end && !tx.isIncome`
- `postPeriodClearedTransactions`: `tx.date > range.end && !tx.isPending && !tx.isIncome && tx.plaidAccountId == account.lunchMoneyId`
- Only processes accounts where `account.type == "credit"`.

After adding these files, update `WeeklyPaydownModel.calculation()` to delegate to `WeeklyPaydownReport.compute()` so the iOS app uses the same path as the Lambda. Delete the duplicated filter methods from `WeeklyPaydownModel` once the model is refactored.

The `Package.swift` `ReportingService` target needs `CryptoKit` only if we add hashing here — we won't, so no dependency changes for this phase.

---

## - [ ] Phase 2: User Account System (FinancePackage + Lambda)

**Skills to read**: `swift-app-architecture:swift-architecture`

### 2a — Domain model (`FinanceCoreSDK`)

Add `UserAccount.swift`:
```swift
public struct UserAccount: Sendable, Codable {
    public let username: String       // partition key in DynamoDB
    public let passwordHash: String   // SHA-256 hex of password
    public let createdAt: String
}
```

Add a static helper on `UserAccount`:
```swift
public static func hashPassword(_ password: String) -> String  // SHA-256 via CryptoKit
```

Add `CryptoKit` to the `FinanceCoreSDK` target in `Package.swift`. On Linux the module is `Crypto` from `swift-crypto`; use `#if canImport(CryptoKit) / import CryptoKit #else import Crypto #endif`. Add `swift-crypto` to `Package.swift` dependencies (already likely present, or add it).

Update `DeviceToken.swift` — add an optional `userId: String?` field. Existing DynamoDB items without this field will decode with `userId = nil`; that's fine.

### 2b — Store protocol + DynamoDB implementation (`NotificationService`)

Add `UserStoreProtocol.swift`:
```swift
public protocol UserStoreProtocol: Sendable {
    func create(_ user: UserAccount) async throws
    func find(username: String) async throws -> UserAccount?
}
```

Add `DynamoDBUserStore.swift` — same `updateItem` pattern used in `DynamoDBDeviceTokenStore`:
- `create()`: `updateItem` with key `["id": .s(user.username)]`, sets `recordType = "user"`, `passwordHash`, `createdAt`.
- `find()`: `scan` with filter `recordType = "user" AND id = :username` (or `getItem` if you store users by username as PK — preferred).

Add `LoggingUserStore.swift` for the stub path (mirrors `LoggingDeviceTokenStore`).

### 2c — Update `DynamoDBDeviceTokenStore`

Update `store(_ token: DeviceToken)` to also write `userId` when non-nil.

Update `fetchAll()` return to include `userId` when present.

### 2d — New Lambda endpoints

In `GetRicherLambda.swift`:

**`POST /api/users/register`** — body: `{username, password}`
- Checks if user already exists (`find(username:)`). If found, return 409 Conflict.
- Creates `UserAccount(username:, passwordHash: UserAccount.hashPassword(password))`.
- Returns `{"status":"ok"}`.

**Update `POST /api/device-tokens`** — body: `{token, environment, username, password}`
- Validates credentials: look up user, compare `hashPassword(password) == user.passwordHash`.
- If invalid, return 401.
- Stores `DeviceToken(tokenString: token, environment: environment, userId: username)`.

Wire `UserStoreProtocol` through `main()` and `handle()` the same way `DeviceTokenStoreProtocol` is wired.

---

## - [ ] Phase 3: iOS — Registration UI & Credential-Aware Token Registration

**Skills to read**: `swift-app-architecture:swift-swiftui`

### 3a — Keychain storage for credentials

`KeychainSDK` already exists. Add helpers (or use the existing `KeychainClient`) to read/write `username` and `password` under separate keychain keys.

### 3b — `UserAccountModel` (iOS app layer)

New `UserAccountModel.swift` — `@Observable @MainActor`:
```swift
@Observable @MainActor
final class UserAccountModel {
    var username: String = ""
    var password: String = ""
    var isRegistered: Bool  // derived from Keychain
    var errorMessage: String?

    func register(backendURL: String) async   // POST /api/users/register
    func saveCredentials()                    // persist to Keychain
    func loadCredentials()                    // read from Keychain on init
}
```

### 3c — Registration UI in Settings

Add a "Account" section to `SettingsView`:
- If not registered: username + password `TextField`/`SecureField` + "Register" button.
- If registered: shows registered username + "Sign Out" (clears keychain) button.

### 3d — Update `NotificationsModel`

Update `sendTokenToBackend(_:)` to read `username` and `password` from `UserAccountModel` (injected via `@Environment`) and include them in the `POST /api/device-tokens` body. If credentials are missing (not yet registered), skip registration and show an error or no-op.

### 3e — Inject `UserAccountModel` into environment

In `FinanceApp.swift`, create and inject `UserAccountModel` alongside the existing `SettingsModel`, `NotificationsModel`, etc.

---

## - [ ] Phase 4: Lambda Daily Paydown Report + CDK Schedule

**Skills to read**: `swift-app-architecture:swift-architecture`

### 4a — Lambda scheduled handler

Update `handleGenerateReport()` (currently called by EventBridge) to:

1. Fetch all credit accounts via `client.fetchPlaidAccounts(token:)`, map DTOs to domain `Account`.
2. Compute `PaydownDateRange` for the current period (`pivotDay: .saturday` — make this a Lambda env var `PIVOT_DAY` defaulting to `saturday`).
3. Fetch transactions from `range.start` to `range.end + 7 days` via `client.fetchTransactions(token:startDate:endDate:)`. Handle pagination (loop until response count < limit).
4. Map `TransactionDTO` → domain `Transaction` (add a `toDomain()` extension on `TransactionDTO` in `LunchMoneySDK`, mirroring how `PersistenceService.Transaction.toDomain()` works).
5. Call `WeeklyPaydownReport.compute(accounts:transactions:pivotDay:)`.
6. Format body: `WeeklyPaydownReport.notificationBody(from:)`.
7. Fetch all tokens from `tokenStore.fetchAll()`.
8. Send push notification to all tokens.
9. Store a `ReviewItem` with the formatted summary (existing behavior, keep it).

### 4b — Add `toDomain()` to `TransactionDTO`

In `LunchMoneySDK`, add `TransactionDTO.toDomain() -> Transaction` mapping the fields that `PaydownCalculation` relies on: `id`, `date`, `payee`, `toBase`, `isIncome`, `isPending`, `plaidAccountId`.

### 4c — CDK schedule update

In `cdk/lib/constructs/lambda-construct.ts`, replace the weekly EventBridge rule with a daily one at 5 AM UTC:
```typescript
schedule: events.Schedule.cron({ minute: '0', hour: '5' })
```

Add a `pivotDay` prop to `LambdaConstructProps` (default `'saturday'`) and inject as `PIVOT_DAY` env var.

---

## - [ ] Phase 5: "Send Report Now" (Lambda endpoint + iOS Settings button)

**Skills to read**: `swift-app-architecture:swift-swiftui`

### 5a — Lambda endpoint

Add `POST /api/send-my-report` — body: `{username, password}`:
- Validate credentials (same as device-token registration).
- Fetch all device tokens, filter to those where `userId == username`.
- Run the paydown report computation (same logic as Phase 4 scheduled handler — extract to a shared private helper `generatePaydownReport()` to avoid duplication).
- Send notification to this user's tokens only.
- Returns `{"status":"ok","notificationsSent":<n>}`.

### 5b — iOS Settings button

In `SettingsView`, under the "Backend" section (or a new "Notifications" section):
- Add a "Send Report Now" `Button`.
- On tap, POST to `/api/send-my-report` using stored credentials and backend URL.
- Show a brief "Sent!" confirmation inline (use a `@State var reportSent: Bool`).

Wire the call through `NotificationsModel` or a new thin method on `UserAccountModel`.

---

## - [ ] Phase 6: Validation

**Skills to read**: none

### Automated
- `swift build` in `FinancePackage` — verifies all new domain types and service methods compile on Linux.
- `xcodebuild build` for the iOS target — verifies no import or model injection breakage.

### Manual — Lambda endpoints
```bash
API=https://qzklnxo41m.execute-api.us-east-1.amazonaws.com/prod

# Register a user
curl -s -X POST $API/api/users/register \
  -H "Content-Type: application/json" \
  -d '{"username":"bill","password":"<pw>"}'

# Re-register device token with credentials (from iOS Re-send button after logging in)
# Verify token appears in DynamoDB with userId = "bill"
aws dynamodb scan --table-name get-richer \
  --filter-expression "recordType = :rt" \
  --expression-attribute-values '{":rt":{"S":"deviceToken"}}' \
  --profile production --region us-east-1

# Send report to just this user
curl -s -X POST $API/api/send-my-report \
  -H "Content-Type: application/json" \
  -d '{"username":"bill","password":"<pw>"}'
# Expect: notification on device with paydown summary

# Smoke-test the scheduled report path
curl -s -X POST $API/api/generate-report
# Expect: notification on all registered devices
```

### Manual — iOS
1. Open Settings → Account section → register with username + password.
2. Tap "Re-send Device Token" — verify token stored with `userId` in DynamoDB.
3. Tap "Send Report Now" — verify push notification arrives with credit card paydown summary.
4. Verify the Weekly Paydown view in the app still works correctly (same numbers as the push notification body).

### CDK schedule
After deploying, confirm the new EventBridge rule fires daily at 5 AM UTC by checking CloudWatch events or waiting for the next fire time and inspecting Lambda logs.
