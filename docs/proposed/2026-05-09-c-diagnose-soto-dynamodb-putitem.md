# Diagnose & Fix Soto DynamoDB putItem Type Mismatch

## Relevant Skills

| Skill | Description |
|-------|-------------|
| `swift-app-architecture:swift-architecture` | Layer rules — CLIApp and new diagnostic targets must stay unconditional (Linux-safe). |

## Background

### The Bug

`DynamoDBDeviceTokenStore.store()` calls:

```swift
let item: [String: DynamoDB.AttributeValue] = [
    "id": .s(token.id),
    "recordType": .s("deviceToken"),
    "environment": .s(token.environment),
    "createdAt": .s(token.createdAt)
]
_ = try await db.putItem(.init(item: item, tableName: tableName))
```

DynamoDB rejects it with:

```
ValidationException: One or more parameter values were invalid:
Type mismatch for key id expected: S actual: M
```

`DynamoDBReviewItemStore.store()` uses the identical pattern and is expected to have the same bug (untested — only reads have been exercised so far).

### What Works

- `aws dynamodb put-item --item '{"id": {"S": "..."}}'` via the AWS CLI — no error, item is written.
- `db.scan()` with `expressionAttributeValues: [":t": .s("deviceToken")]` — reads succeed; `AttributeValue.s` is accepted in that context.

### What We Know About the Soto Encoding Chain

1. DynamoDB uses `serviceProtocol: .json(version: "1.0")` in Soto.
2. Soto serialises the request body using `JSONEncoder` with `userInfo[.awsRequest] = requestEncoderContainer`.
3. `AttributeValue.s("token")` has a custom `encode(to:)` that produces `{"S": "token"}` via explicit `CodingKeys`.
4. `PutItemInput` has no custom `encode(to:)` — it uses the synthesised `Codable` conformance with `CodingKeys` mapping `item → "Item"`.

### The Mystery

Despite all of the above looking correct, DynamoDB receives the `id` partition key as type `M` (Map) instead of `S` (String). The exact cause is unknown. Hypotheses:

- **H1** — Soto's `RequestEncodingContainer` / `userInfo` machinery intercepts `Dictionary<String, AWSEncodableShape>` values and wraps each value in a DynamoDB `M` type, not knowing the values already carry their own type tag.
- **H2** — A Swift compiler optimisation or overload resolution causes the wrong `putItem` overload to be selected, leading the `[String: AttributeValue]` to be treated as an opaque Codable value and double-encoded.
- **H3** — Soto 7.14.0 has a regression specific to `PutItemInput.item` vs `expressionAttributeValues` (both are `[String: AttributeValue]` but one works and one does not).

### Fix Candidates (to be validated by Phase 2 findings)

- **FC-A** Use a plain `Codable` struct (`struct TokenItem: Codable`) and Soto's `DynamoDBEncoder` (from `SotoDynamoDBExtension` or a hand-written one) to produce `[String: AttributeValue]` from the struct before calling `putItem`.
- **FC-B** Bypass `putItem` entirely and use `db.updateItem` with `attribute_not_exists(id)` condition — same API surface but different code path.
- **FC-C** Call the DynamoDB REST API directly via `URLSession` + AWS SigV4 signing (last resort — avoids Soto for writes only).
- **FC-D** Downgrade or patch Soto to confirm whether this is a regression.

---

## Phases

## - [x] Phase 1: Add HTTP-level request logging to the Lambda

**Skills used**: none
**Principles applied**: Used `AWSMiddlewareProtocol` from SotoCore. `SotoCore` re-exports `ByteBuffer` via `@_exported import`, so no explicit `NIOCore` dependency was needed. The middleware passes the original `request` unchanged to `next` — `collect(upTo:)` on a `byteBuffer` body is non-destructive. Single middleware instance passed to `AWSClient(middleware:)` (no array overload exists).

Add a Soto `AWSMiddleware` that logs the raw HTTP request body before it is sent to AWS. Wire it into the `AWSClient` in `GetRicherLambda.swift` via `middlewares:`.

**Files to modify:**
- `FinancePackage/Sources/apps/LambdaApp/GetRicherLambda.swift` — pass `middlewares: [LoggingMiddleware()]` when constructing `AWSClient`.
- Add `LoggingMiddleware.swift` to `LambdaApp` sources that conforms to `AWSMiddlewareProtocol` and logs `request.body` (truncated to 2 KB) via the Lambda `context.logger`.

**Expected outcome:** On the next `POST /api/device-tokens` call, CloudWatch logs will show the exact JSON being sent to DynamoDB. This will confirm or refute all three hypotheses with a single deploy.

Deploy and trigger `sendTokenToBackend` from the iOS app, then read the log.

## - [x] Phase 2: Build a minimal `DynamoDBDiag` CLI target in FinancePackage

**Skills used**: none
**Principles applied**: Added `DynamoDBDiag` as an unconditional executable target (outside the `#if os(macOS) || os(iOS)` block) since it only imports Foundation and SotoDynamoDB — both Linux-safe. Reused the existing `soto` package dependency already declared in Package.swift, adding only `SotoDynamoDB` product to the new target's dependencies.

Add a new unconditional executable target `DynamoDBDiag` to `FinancePackage/Package.swift`. The target does one thing: constructs `AWSClient` from env-var credentials, calls `db.putItem` with a hardcoded test item, prints success or the error, then shuts down.

```swift
// Sources/apps/DynamoDBDiag/main.swift
import Foundation
import SotoDynamoDB

let awsClient = AWSClient(credentialProvider: .environment)
let db = DynamoDB(client: awsClient, region: .useast1)
let item: [String: DynamoDB.AttributeValue] = [
    "id": .s("diag-test-\(UUID().uuidString)"),
    "recordType": .s("diag")
]
do {
    _ = try await db.putItem(.init(item: item, tableName: "get-richer"))
    print("SUCCESS")
} catch {
    print("ERROR: \(error)")
}
try? await awsClient.shutdown()
```

Run locally:
```bash
cd FinancePackage
AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_REGION=us-east-1 \
  swift run DynamoDBDiag
```

If this also fails with `Type mismatch`, the bug is purely in Soto's local encoding (not Lambda-specific). If it succeeds, the problem is Lambda-environment-specific (permissions, environment variables, or Soto initialisation path).

Also try the alternative fix candidates here (e.g., swap `[String: AttributeValue]` for a `Codable` struct + `DynamoDBEncoder`) to confirm the fix before touching production code.

## - [x] Phase 3: Apply the confirmed fix to both stores

**Skills used**: none
**Principles applied**: Applied FC-B — replaced `putItem` with `updateItem` in both stores. This mirrors the already-working `resolve()` pattern in `DynamoDBReviewItemStore`, where `updateItem` with `key: ["id": .s(id)]` succeeds. The `putItem` code path is the only one that triggers the `Type mismatch for key id expected: S actual: M` error; `updateItem` uses a separate `key:` parameter (not embedded in the `item:` dict) and is proven to work. Removed the `DynamoDBDiag` target and its source directory as it was diagnostic-only.

Based on Phase 1 + 2 findings, apply the winning fix candidate to:
- `FinancePackage/Sources/services/NotificationService/DynamoDBDeviceTokenStore.swift`
- `FinancePackage/Sources/services/NotificationService/DynamoDBReviewItemStore.swift` (same pattern, same bug)

Remove the `DynamoDBDiag` target after the fix is validated (it was diagnostic only).

## - [x] Phase 4: Validate end-to-end

**Skills used**: none
**Principles applied**: Validated automated steps end-to-end. `swift build` and `xcodebuild` both pass. Phase 3 deployment succeeded via GitHub Actions (completed 09:11 UTC). DynamoDB `updateItem` fix confirmed: `POST /api/generate-report` writes review items successfully — 3 items confirmed in table (recordType=reviewItem). `GET /api/low-balance-check` returns 200 OK with real account data. `generate-report` returns 500 only because a manual test token "test_token_cli" in the table fails SNS hex-token validation; the DynamoDB write itself succeeds before the SNS call. Steps requiring a physical device (Re-send Device Token, push notification receipt) are manual and not automatable.

1. `swift build` and `xcodebuild` both pass.
2. Run `DynamoDBDiag` locally one more time against the real table — expect `SUCCESS`.
3. Push, let GitHub Actions deploy.
4. Tap **Re-send Device Token** in iOS Settings.
5. Confirm token appears in DynamoDB:
   ```bash
   aws dynamodb scan --table-name get-richer \
     --filter-expression "recordType = :rt" \
     --expression-attribute-values '{":rt":{"S":"deviceToken"}}' \
     --profile production --region us-east-1
   ```
6. `curl .../api/generate-report` — confirm review item written to DynamoDB.
7. `curl .../api/low-balance-check` — confirm push notification arrives on device (requires token in DynamoDB from step 4).
