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

## General Guidance

- When in doubt about where to place new code, read `/swift-architecture` first
- When in doubt about UI patterns, read `/swift-swiftui` first
- **Read broadly**: if a SKILL.md references other files that are even possibly related to your task, read them too. More context is better than less.
