## Relevant Skills

| Skill | Description |
|-------|-------------|
| `/swift-architecture` | Code placement, layer definitions, dependency rules |

## Background

The iOS app currently logs to a local file via `FileLogHandler` (bootstrapped in `GetRicherLogging.bootstrap()`). When errors occur in production there is no way to read them remotely. The goal is to add remote log shipping so errors are visible in AWS CloudWatch Logs Insights.

**Chosen architecture:**
- `swift-otel` (v1.x) provides an `OTelLogHandler` that implements `swift-log`'s `LogHandler` protocol. After bootstrapping, all `Logger` calls in the app are automatically intercepted and exported via OTLP.
- The OTLP HTTP exporter points at a new Lambda endpoint (`POST /api/otlp/logs`) rather than CloudWatch directly, so the iOS app needs no AWS credentials — it authenticates with the existing username/password scheme via a custom request header.
- The Lambda validates credentials, injects the required CloudWatch headers (`x-aws-log-group`, `x-aws-log-stream`), signs the request with SigV4 using its own IAM role, and forwards the raw OTLP body to `https://logs.{region}.amazonaws.com/v1/logs`.

**Key facts about `swift-otel`:**
- `OTel.bootstrap()` calls `LoggingSystem.bootstrap` internally — it can only be called once.
- It returns an opaque `Service` type whose `run()` method must be kept alive for batch export to work. On iOS this means a long-lived `Task` started at app launch.
- `swift-otel` declares iOS 16.0+ as a supported platform and compiles cleanly, but it is server-oriented. The `ServiceGroup` pattern is not used; instead, run the service in a detached `Task` and cancel it on app termination.
- To retain local file logging alongside OTel, use `MultiplexLogHandler([fileHandler, otelHandler])` instead of calling `OTel.bootstrap()` directly. This requires manually constructing `OTelLogHandler` and its processor.

**Existing pieces:**
- `LoggingSDK/GetRicherLogging.swift` — current bootstrap entry point; `FinanceApp.init()` calls `GetRicherLogging.bootstrap()`
- `LoggingSDK` already uses `@_exported import Logging` so all targets that import `LoggingSDK` get `swift-log` for free
- Lambda already has Soto (`aws-sdk-swift`-compatible signing) and the IAM role to write CloudWatch Logs

## Phases

## - [x] Phase 1: Lambda OTLP Proxy Endpoint

**Skills used**: `swift-architecture`
**Principles applied**: Handler follows the existing `private static func` pattern in `GetRicherLambda`. SigV4 signing is implemented directly using `swift-crypto` (already a package dependency) rather than adding a Soto signing dependency — Lambda execution role credentials are read from the standard AWS environment variables. Local dev mode (detected via `LUNCH_MONEY_TOKEN` env var) short-circuits the handler before credential validation since `LoggingUserStore` always returns nil. `HTTPTypes` and `Crypto` were added as explicit `LambdaApp` dependencies (they were only transitive before).

Add a Lambda route that receives OTLP log records from the iOS app and forwards them to CloudWatch.

**Tasks:**
- Add route `POST /api/otlp/logs` in `GetRicherLambda.handleAPIGateway`
- Add handler `handleOTLPLogs(event:userStore:context:)`:
  - Read credentials from custom headers `X-GetRicher-Username` and `X-GetRicher-Password`; return 401 if missing or invalid
  - Read the raw OTLP body from `event.body` (base64-decoded if needed — API Gateway may base64-encode binary bodies; check `event.isBase64Encoded`)
  - Construct a `URLRequest` to `https://logs.\(region).amazonaws.com/v1/logs`
  - Add headers: `Content-Type: application/x-protobuf`, `x-aws-log-group: /getricher/ios`, `x-aws-log-stream: <username>`
  - Sign the request with SigV4 using Soto's `AWSSigner` (the Lambda's IAM credentials are available via `AWSClient`)
  - Forward with `URLSession.shared.data(for:)` and return the upstream status code
- CDK (`LambdaConstruct` or IAM policy): add `logs:PutLogEvents`, `logs:CreateLogStream`, `logs:DescribeLogStreams` on `arn:aws:logs:*:*:log-group:/getricher/ios:*`
- CDK: add `logs:CreateLogGroup` on `arn:aws:logs:*:*:log-group:/getricher/ios`
- The local/environment dev path (when `LUNCH_MONEY_TOKEN` is set) should route to `LoggingOTLPHandler` that just prints the OTLP body to console

## - [x] Phase 2: Add swift-otel + OTel Bootstrap in LoggingSDK

**Skills used**: `swift-architecture`
**Principles applied**: Moved `LoggingSDK` and `LogsFeature` targets to the `#if os(macOS) || os(iOS)` block since Lambda (Linux) doesn't use them and `swift-otel` is iOS/macOS-only. Added `swift-service-lifecycle` as an explicit dependency alongside `swift-otel` because `public import ServiceLifecycle` in swift-otel's source does not re-export the module to downstream targets in Swift 6.0. `OTelLoggingService` uses `OTel.makeLoggingBackend(configuration:)` (the public multiplex-friendly API) rather than `OTel.bootstrap()`, so the caller retains control of `LoggingSystem.bootstrap`. Existing `GetRicherLogging.bootstrap()` call in `FinanceApp` continues to work unchanged (nil default for `otelService`).

Add `swift-otel` as a dependency and update `LoggingSDK` to configure OTel log export.

**Package.swift changes:**
- Add `swift-otel` to the `#if os(macOS) || os(iOS)` block:
  ```swift
  .package(url: "https://github.com/swift-otel/swift-otel.git", from: "1.0.0")
  ```
- Add `OTel` product to `LoggingSDK` target dependencies (inside the macOS/iOS block)

**LoggingSDK changes:**
- Add `OTelLoggingService.swift` — a type that:
  - Takes `baseURL: String`, `username: String`, `password: String` as init params
  - Creates an `OTelLogRecordProcessor` (batch) backed by an `OTelOTLPHTTPLogRecordExporter` configured with:
    - Endpoint: `\(baseURL)/api/otlp/logs`
    - Custom headers: `X-GetRicher-Username: <username>`, `X-GetRicher-Password: <password>`
  - Exposes `makeLogHandler(label:) -> LogHandler` returning `OTelLogHandler` wired to the processor
  - Conforms to `Service` (or wraps the underlying OTel service) so the caller can `await service.run()`
- Update `GetRicherLogging.bootstrap()` to accept an optional `OTelLoggingService`:
  ```swift
  public static func bootstrap(otelService: OTelLoggingService? = nil, logLevel: Logger.Level = .info)
  ```
  - When `otelService` is nil: existing `FileLogHandler` only (unchanged behaviour for demo mode / no credentials)
  - When `otelService` is provided: `MultiplexLogHandler([fileHandler, otelService.makeLogHandler(label:)])`
- Return the `OTelLoggingService?` from `bootstrap()` so the caller can run it

## - [ ] Phase 3: iOS App Lifecycle Integration

**Skills to read**: `/swift-architecture`, `/swift-swiftui`

Wire the OTel service into `FinanceApp` so it starts at launch, keeps running, and flushes on background.

**`FinanceApp.swift` changes:**
- After credentials are available (non-demo mode, `backendURL` is set, username/password in Keychain), create `OTelLoggingService` and pass it to `GetRicherLogging.bootstrap(otelService:)`
- Store the returned service in a `@State private var otelService: OTelLoggingService?`
- In the `WindowGroup` body, add `.task` to start the service:
  ```swift
  .task {
      guard let service = otelService else { return }
      try? await service.run()  // runs until task is cancelled
  }
  ```
- Handle app backgrounding — add `.onReceive(NotificationCenter... UIApplication.didEnterBackgroundNotification)` to trigger a flush: call `service.forceFlush()` if the OTel service exposes it, or cancel and restart the task
- In demo mode, no `OTelLoggingService` is created; `FileLogHandler` only (no change)
- When `settingsModel.modeChangeCount` fires (mode switch), cancel the existing OTel task and restart with new credentials if applicable — this mirrors the existing `handleModeChange()` pattern

## - [ ] Phase 4: Add Logging Throughout the iOS App

**Skills to read**: `/swift-architecture`, `/swift-swiftui`

Add a `Logger` instance to every model and log all errors and significant user actions. Since `LoggingSDK` re-exports `swift-log`, any file that already imports `LoggingSDK` (or `Logging` directly) can add a logger with one line.

**Convention:** add a private logger at the top of each model:
```swift
private let logger = Logger(label: "com.getricher.<ModelName>")
```

**`TransactionsModel.swift`:**
- Already has some logging — audit and fill gaps
- `logger.info` on sync start with date range
- `logger.error` on sync failure (already present — confirm it's wired)
- `logger.info` on sync success with account/transaction counts

**`UserAccountModel.swift`:**
- `logger.info("Registration attempt: \(username)")` before registration call
- `logger.error("Registration failed: ...")` in all catch/error branches
- `logger.info("Login attempt: \(username)")` before login
- `logger.error("Login failed (HTTP \(code))")` on non-2xx
- `logger.info("Send report triggered by user: \(username)")` in send-report action
- `logger.error("Send report failed: ...")` in catch

**`ReviewInboxModel.swift`:**
- `logger.info("Load review items")` at start of `loadItems()`
- `logger.error("Load review items failed: \(error)")` in catch
- `logger.info("Resolve item \(item.id) status=\(status)")` in `resolve(_:status:)`

**`NotificationsModel.swift`:**
- `logger.info("Request notification permission")` in `requestPermissionAndRegister()`
- `logger.error("Device token registration failed: \(error)")` in `handleRegistrationError`
- `logger.info("Device token sent to backend")` on success in `sendTokenToBackend`
- `logger.error("Send token to backend failed: \(error)")` in catch

**`AdminModel.swift`:**
- `logger.info("Admin: load users")` / `logger.error(...)` in `loadUsers`
- `logger.info("Admin: delete user \(username)")` / `logger.error(...)` in `deleteUser`
- `logger.info("Admin: update LM token for \(username)")` / `logger.error(...)` in `updateLMToken`
- Same pattern for `loadReports`, `deleteReport`

**`AccountsModel.swift`** (if it has async fetch calls):
- `logger.error` on any fetch failure

**General rule:** every `catch` block that currently sets `errorMessage` or silently fails should also call `logger.error`. Every user-initiated action (button tap resulting in an async call) should log at `.info` when it starts. No need to log purely derived/computed values.

## - [ ] Phase 6: Document Log Reading in CLAUDE.md

**Skills to read**: none required

Add a section to `CLAUDE.md` explaining how to read iOS user logs from CloudWatch so this is discoverable in future sessions.

**`CLAUDE.md` addition** — add a new top-level section `## Reading iOS Logs` covering:

- **Log group:** `/getricher/ios`
- **Log stream per user:** one stream per username (e.g., `bill`)
- **CloudWatch Logs Insights query** to fetch recent errors for a user:
  ```
  fields @timestamp, severity, body
  | filter @logStream = "<username>"
  | filter severity >= "ERROR"
  | sort @timestamp desc
  | limit 50
  ```
- **AWS CLI equivalent** (usable directly from Claude Code without opening the console):
  ```bash
  aws logs filter-log-events \
    --log-group-name /getricher/ios \
    --log-stream-name <username> \
    --filter-pattern ERROR \
    --profile production \
    --start-time $(date -v-1H +%s000) \
    --output json | python3 -c "
  import sys, json
  for e in json.load(sys.stdin)['events']:
      print(e['timestamp'], e['message'][:200])
  "
  ```
- **Fetching all users' recent logs** (admin view):
  ```bash
  aws logs describe-log-streams \
    --log-group-name /getricher/ios \
    --profile production \
    --query 'logStreams[].logStreamName' \
    --output json
  ```
- Note that logs take up to ~10 seconds to appear after the iOS batch processor flushes (configurable via `OTelLoggingService` batch interval)

## - [ ] Phase 7: Validation

**Skills to read**: none required

Verify logs flow from iOS through Lambda to CloudWatch end-to-end, and confirm the CLAUDE.md docs are accurate.

**Lambda unit test:**
- Add a test in `LambdaApp` (or a new test target) that sends a mock OTLP body to `handleOTLPLogs` with valid and invalid credentials, asserting correct status codes

**End-to-end check:**
1. Build and run the app on a real device (not simulator — needs real network)
2. Trigger a known error path (e.g., wrong password on login)
3. Wait up to 10 seconds for the batch processor to flush
4. Query CloudWatch Logs Insights:
   ```
   fields @timestamp, @message
   | filter @logStream = "bill"
   | sort @timestamp desc
   | limit 20
   ```
5. Confirm the error log record appears with correct severity, message, and trace metadata

**CLI smoke test (no device needed):**
```bash
# Send a synthetic OTLP log record to the Lambda proxy
curl -s -X POST https://qzklnxo41m.execute-api.us-east-1.amazonaws.com/prod/api/otlp/logs \
  -H "Content-Type: application/x-protobuf" \
  -H "X-GetRicher-Username: bill" \
  -H "X-GetRicher-Password: testpass123" \
  --data-binary @/tmp/sample-otlp-logs.bin
```
(A sample OTLP protobuf binary can be generated with `otelcol` or any OTel test utility)

**Success criteria:**
- Lambda returns 200 for valid credentials and valid OTLP body
- Lambda returns 401 for missing/invalid credentials
- Log records appear in `/getricher/ios` log group in CloudWatch within 30 seconds of the iOS app flushing
- Existing file logging still works (logs still appear in the on-device file)
- Demo mode is unaffected — no OTel traffic when running in demo
