# CLAUDE.md — Finance Project

## Architecture Skills

This project follows the Swift app architecture defined at https://github.com/gestrich/swift-app-architecture. When working on this codebase, **always** read the following skills before making changes:

### `/swift-architecture` — Code Placement & Structure
- Read the main `SKILL.md` **and all files it references** (layer definitions, dependency rules, placement guidance, feature creation, configuration, code style, reference examples)
- Use when: adding new files, deciding where code belongs, creating features, reviewing architectural compliance
- Err on the side of reading more referenced files than you think you need

### `/swift-swiftui` — UI Patterns
- Read the main `SKILL.md` **and all files it references** (enum-based state, model composition, dependency injection, view state vs model state, view identity, observable model conventions)
- Use when: building SwiftUI views, creating observable models, implementing state management, connecting use cases to UI
- Err on the side of reading more referenced files than you think you need

### `fetch-lambda-data` (`.claude/skills/fetch-lambda-data.md`) — Lambda Debug Guide
- `curl` examples for all key endpoints, CLI usage against production, DynamoDB verification, and CloudWatch log inspection
- Use when: debugging Lambda responses, verifying DynamoDB data, or testing endpoints manually

## UI Tests

UI tests live in `GetRicherUITests/GetRicherUITests.swift`. Every screen in the app should have a UI test that captures a screenshot.

### Running UI Tests

```bash
# Clean any previous result bundle
rm -rf /tmp/GetRicherResults

# Run a specific test
xcodebuild test \
  -project GetRicher.xcodeproj \
  -scheme GetRicher \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:GetRicherUITests/GetRicherUITests/testPieChartScreenshot \
  -resultBundlePath /tmp/GetRicherResults \
  -allowProvisioningUpdates

# Run all UI tests
xcodebuild test \
  -project GetRicher.xcodeproj \
  -scheme GetRicher \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:GetRicherUITests \
  -resultBundlePath /tmp/GetRicherResults \
  -allowProvisioningUpdates
```

### Extracting Screenshots from Results

```bash
# 1. Find the attachment payload ID
xcrun xcresulttool get test-results activities \
  --path /tmp/GetRicherResults \
  --test-id "GetRicherUITests/testPieChartScreenshot()" \
  2>&1 | python3 -c "
import sys, json
data = json.load(sys.stdin)
def find(obj):
    if isinstance(obj, dict):
        if 'payloadId' in obj:
            print(obj['payloadId'])
        for v in obj.values(): find(v)
    elif isinstance(obj, list):
        for v in obj: find(v)
find(data)"

# 2. Export the screenshot using the payload ID
xcrun xcresulttool export object --legacy \
  --path /tmp/GetRicherResults \
  --output-path /tmp/screenshot.png \
  --id "<payloadId>" \
  --type file
```

### When to Run UI Tests

- **After any UI change** — run the affected test(s) to capture updated screenshots
- **Before opening a PR** — run all UI tests to verify no visual regressions
- Screenshots should be attached to PRs when UI changes are involved

### Attaching Screenshots to PRs

Screenshots go in the `screenshots/` directory at the repo root. To include them in a PR:

1. Extract the screenshot from the `.xcresult` bundle (see above)
2. Resize if needed: `sips -Z 800 /tmp/screenshot.png --out screenshots/my-feature.png`
3. Save to `screenshots/` with a descriptive name
4. Commit the screenshot with your branch
5. Reference in the PR body using a relative path: `![Description](screenshots/my-feature.png)`

This ensures screenshots are versioned with the code and visible directly in the PR on GitHub.

### Writing UI Tests

Each test should:
1. Launch the app (`XCUIApplication().launch()`)
2. Wait for key UI elements to appear (`waitForExistence(timeout:)`)
3. Capture a screenshot and add it as a kept attachment:
   ```swift
   let screenshot = app.screenshot()
   let attachment = XCTAttachment(screenshot: screenshot)
   attachment.name = "DescriptiveName"
   attachment.lifetime = .keepAlways
   add(attachment)
   ```

### Test ID Format

When using `xcresulttool`, test IDs use the format: `GetRicherUITests/testMethodName()`

## Deployment & Infrastructure

See [docs/deployment.md](docs/deployment.md) for the full deployment guide. Key things to know when touching Lambda, CDK, or GitHub Actions:

- GitHub Actions needs `permissions: id-token: write` in the *calling* workflow for OIDC to pass through to a reusable workflow
- Do not use `if: success()` on a job that has a `uses:` key — GitHub forbids it and fails with `startup_failure`
- The `dev` GitHub environment must exist before the deploy workflow can run
- `build.sh` extracts `Package.resolved` from the Linux Docker builder image — do not short-circuit this or the Linux build will hang
- Any target importing `SwiftData`, `SwiftUI`, `UIKit`, or `AppKit` must be in a `#if os(macOS) || os(iOS)` block in `Package.swift`; `LambdaApp` and `ClientService` must be unconditional

## Reading iOS Logs

iOS app logs are shipped to CloudWatch via the OTLP Lambda proxy.

- **Log group:** `/getricher/ios`
- **Log stream per user:** one stream per username (e.g., `bill`)

### CloudWatch Logs Insights query (console)

```
fields @timestamp, severity, body
| filter @logStream = "<username>"
| filter severity >= "ERROR"
| sort @timestamp desc
| limit 50
```

### AWS CLI — recent errors for a specific user

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

### AWS CLI — list all user streams (admin view)

```bash
aws logs describe-log-streams \
  --log-group-name /getricher/ios \
  --profile production \
  --query 'logStreams[].logStreamName' \
  --output json
```

> Logs take up to ~10 seconds to appear after the iOS batch processor flushes (configurable via `OTelLoggingService` batch interval).

## General Guidance

- When in doubt about where to place new code, read `/swift-architecture` first
- When in doubt about UI patterns, read `/swift-swiftui` first
- **Read broadly**: if a SKILL.md references other files that are even possibly related to your task, read them too. More context is better than less.
