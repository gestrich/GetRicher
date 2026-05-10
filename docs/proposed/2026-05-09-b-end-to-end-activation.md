# End-to-End Activation: Push Notifications & LunchMoney Reports

## Relevant Skills

| Skill | Description |
|-------|-------------|
| `swift-app-architecture:swift-swiftui` | SwiftUI Model-View patterns — observable models, dependency injection, view state. |
| `swift-app-architecture:swift-architecture` | 4-layer Swift architecture — layer responsibilities, dependency rules, placement. |

## Background

All the code for push notifications, weekly reports, and LunchMoney data fetching was written in Phases 1–8, but the system has never actually run end-to-end. Three categories of gaps block it:

1. **Missing AWS resources** — `LUNCH_MONEY_TOKEN` secret in Secrets Manager and an SNS iOS Platform Application do not exist yet.
2. **CDK wiring gaps** — The Lambda's Secrets Manager IAM grant only covers a placeholder secret, not `LUNCH_MONEY_TOKEN`; `SNS_PLATFORM_ARN` is never injected as a Lambda environment variable.
3. **iOS configuration gap** — `backendURL` (the API Gateway URL the app POSTs device tokens to) is read from `UserDefaults` but there is no UI or pre-configured value to set it, so device tokens are never sent.

**What is needed from Bill before Phase 3 can run:**
- **LunchMoney API token** — from lunchmoney.app → Settings → Developers → "Request API Access" → copy the token.
- **Apple APNs .p8 key** — from developer.apple.com → Certificates, Identifiers & Profiles → Keys → create a key with "Apple Push Notifications service (APNs)" capability. Download the `.p8` file, note the Key ID and Team ID.

**What you can verify yourself (no device needed for first smoke test):**
- `curl` the `/` endpoint and see a real account balance summary.
- `curl` `/api/generate-report` and see a review item appear in DynamoDB.

**Full push notification smoke test requires a physical iOS device** (simulators don't receive APNs).

## Phases

## - [ ] Phase 1: Fix CDK — Secrets Manager grant + SNS_PLATFORM_ARN

Update `cdk/lib/constructs/lambda-construct.ts` to:

1. **Fix Secrets Manager IAM** — the current grant only covers the placeholder secret `get-richer/placeholder`. Replace it with a broad `secretsmanager:GetSecretValue` policy statement that covers any secret the Lambda needs (or scope it to `LUNCH_MONEY_TOKEN` specifically). The simplest approach: add an `iam.PolicyStatement` granting `secretsmanager:GetSecretValue` on `arn:aws:secretsmanager:*:*:secret:LUNCH_MONEY_TOKEN*` alongside the existing placeholder grant.

2. **Inject `SNS_PLATFORM_ARN`** — add it to the Lambda `environment` block. It should be read from a CDK context value or a construct prop so it can be supplied at deploy time without hardcoding. Add a `snsPlatformArn` prop to `LambdaConstructProps` (optional string, defaults to empty string) and pass it through from `get-richer-stack.ts`. Read it from CDK context in `bin/get-richer.ts` via `app.node.tryGetContext('snsPlatformArn') ?? ''`.

3. **Inject `LOW_BALANCE_THRESHOLD`** — similarly add an optional prop (default `'100'`) so Bill can tune the alert threshold without redeploying code.

This phase is code-only; no AWS resources are touched yet.

## - [ ] Phase 2: Add backend URL to iOS Settings

The iOS `SettingsView` needs a text field that lets Bill type in the API Gateway URL. `SettingsModel` should persist it to `UserDefaults` under key `"backendURL"`. `NotificationsModel.sendTokenToBackend()` already reads this key — no change needed there.

Specifically:
- Add `@AppStorage("backendURL") var backendURL: String = ""` to `SettingsModel` (or directly to `SettingsView` if that's simpler given the existing model shape).
- Add a labeled `TextField("https://...", text: $backendURL)` in `SettingsView` under a "Backend" section.
- Keep the field autocorrect-disabled and set keyboard type to URL.

**The API Gateway URL to enter** comes from the CDK stack output `ApiGatewayUrl` printed during `cdk deploy`. It looks like `https://<id>.execute-api.<region>.amazonaws.com/prod/`.

## - [ ] Phase 3: Create AWS resources (Bill's action)

Bill needs to run the following once. Exact commands to copy-paste:

**a. Create LunchMoney token secret:**
```bash
aws secretsmanager create-secret \
  --name LUNCH_MONEY_TOKEN \
  --secret-string "<paste-token-here>" \
  --region us-east-1
```

**b. Create SNS iOS Platform Application (APNs sandbox first):**
```bash
# Read your .p8 key contents:
P8=$(cat /path/to/AuthKey_KEYID.p8 | tr -d '\n')

aws sns create-platform-application \
  --name GetRicherIOS-Sandbox \
  --platform APNS_SANDBOX \
  --attributes \
    PlatformCredential="$P8",\
    PlatformPrincipal="<KEY_ID>",\
    ApplePlatformTeamID="<TEAM_ID>",\
    ApplePlatformBundleID="com.gestrich.finance" \
  --region us-east-1
```

Note the returned `PlatformApplicationArn` — it looks like:
`arn:aws:sns:us-east-1:123456789012:app/APNS_SANDBOX/GetRicherIOS-Sandbox`

**c. Supply the ARN to CDK context for the next deploy:**
In `cdk/cdk.json`, add to the `context` object:
```json
"snsPlatformArn": "arn:aws:sns:us-east-1:123456789012:app/APNS_SANDBOX/GetRicherIOS-Sandbox"
```

## - [ ] Phase 4: Deploy

Push all CDK changes and let GitHub Actions deploy:

```bash
git add cdk/ Finance/
git commit -m "Wire SNS_PLATFORM_ARN, Secrets Manager grant, and backend URL settings UI"
git push origin main
```

GitHub Actions → `deploy_dev.yml` builds the Lambda and runs `cdk deploy`. After it completes, grab the `ApiGatewayUrl` from the Actions log (it's in the CDK outputs).

Enter that URL into the iOS Settings screen (Phase 2) and run the app on a real device.

## - [ ] Phase 5: Validation

**Smoke test 1 — LunchMoney data (no device needed):**
```bash
API=https://<id>.execute-api.us-east-1.amazonaws.com/prod
curl "$API/"
# Expect: JSON with account balances from your real Lunch Money data
```

**Smoke test 2 — Generate a report and review item:**
```bash
curl -X POST "$API/api/generate-report"
# Expect: {"status":"ok"} and a new item in DynamoDB
```

**Smoke test 3 — Device token registration (real device required):**
1. Run the app on a physical device.
2. Accept the push notification permission prompt.
3. Check `SettingsView` → backend URL is set to the API Gateway URL.
4. In AWS Console → DynamoDB → `get-richer` table → scan for an item with `recordType = "deviceToken"`.

**Smoke test 4 — End-to-end push (real device required):**
```bash
curl "$API/api/low-balance-check"
# If any account is below $100, a push notification should arrive on the device.
```

**Smoke test 5 — Review Inbox:**
1. Tap the Inbox tab in the app.
2. Verify the generated report item appears.
3. Swipe to approve — verify `itemStatus` changes to `resolved` in DynamoDB.

**If push notification is not received:** Check Lambda logs in CloudWatch (`/aws/lambda/get-richer`) for SNS errors. Common causes: APNs certificate mismatch, device token environment mismatch (sandbox vs production), or bundle ID mismatch.
