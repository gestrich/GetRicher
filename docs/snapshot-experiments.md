# Snapshot Experiment PR Guidelines

## Purpose

Each experiment PR tests a different image capture technique from a background/daemon process. PRs should follow a consistent format so results are comparable.

## PR Summary Template

Each experiment PR summary should include:

### 1. Technique Name
What capture method was used (e.g., `ImageRenderer in swift test`, `Aqua launchctl screencapture`, `xcodebuild UI test`).

### 2. Environment
- **Process context:** Was the capturing process running in a background launchd session, Aqua session, SSH, CI, etc.?
- **Display state:** Was the computer's display awake or asleep? Was a user logged in to the GUI?
- **Session type:** Background (no window server access) vs Aqua (GUI session access)

### 3. How It Works
Brief technical description of the capture pipeline — what APIs are used, what the data flow looks like (e.g., SwiftUI view → ImageRenderer → CGImage → PNG).

### 4. Limitations
What this technique can and can't do (e.g., no interactive state, requires Screen Recording permission, simulator required, etc.).

### 5. Image Details
- **File name and path** in the repo (e.g., `screenshots/demo_mode_banner_snapshot.png`)
- **Dimensions** (e.g., 800×50 @2x)
- **Inline preview** of the image in the PR body

### 6. Verdict
Did it work? Any issues? How does it compare to other techniques?

## Experiments Log

| # | Technique | Display State | Process Context | Worked? | PR |
|---|-----------|--------------|-----------------|---------|-----|
| 1 | `ImageRenderer` in `swift test` | Awake (GUI logged in) | Background launchd session (OpenClaw daemon) | ✅ Yes | #24 |
