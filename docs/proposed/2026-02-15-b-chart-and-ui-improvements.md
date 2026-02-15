## Relevant Skills

| Skill | Description |
|-------|-------------|
| `swift-architecture` | 4-layer architecture (Apps, Features, Services, SDKs) — layer responsibilities, dependency rules, placement guidance, feature creation, code style |
| `swift-swiftui` | SwiftUI Model-View patterns — enum-based state, model composition, dependency injection, view state vs model state, observable model conventions |

## Background

Bill reviewed the Finance app and identified three UI improvements:

1. The pie chart has amount labels that get clipped when there are many small slices — too many overlapping annotations.
2. When running in demo mode, there's no visual indicator, which could confuse users into thinking demo data is real.
3. In checking accounts, deposits appear as negative amounts in the "Top 10 Vendors" view. Need to allow filtering between credits, debits, and all — defaulting to debits.

The app follows the 4-layer Swift architecture with Swift Charts (`SectorMark`, `BarMark`) for data visualization.

## Phases

## - [ ] Phase 1: Fix pie chart label clipping

**Skills to read**: `swift-swiftui`, `swift-architecture`

The pie chart in `CombinedView` uses `.annotation(position: .overlay)` which causes labels to clip when slices are small. Explore Apple Charts API alternatives:

- **Option A (preferred):** Remove overlay annotations from `SectorMark`. Use `.foregroundStyle(by:)` legend instead of `.chartLegend(.hidden)`, and show amounts in the legend or a separate list below the chart.
- **Option B:** Use `.annotation(position: .outside)` with leader lines if available in the Charts API version.
- **Option C:** Only annotate slices above a percentage threshold (e.g., >5% of total), hiding labels for small slices.

**Files to modify**: `Finance/CombinedView.swift`, `Finance/VendorSpendingView.swift`

**Expected outcome:** Pie chart labels are readable regardless of vendor count. No clipping. Both chart views look cohesive.

## - [ ] Phase 2: Add demo mode indicator on main screen

**Skills to read**: `swift-swiftui`, `swift-architecture`

When `isDemoMode` is true in `FinanceApp.init()`, the main screen (`CombinedView`) should display a visible "Demo Mode" badge or banner.

- Pass `isDemoMode` as an environment value or init parameter to `CombinedView`
- Display a persistent banner (e.g., `Text("Demo Mode")` with a yellow/orange background) at the top of the scroll view or as a navigation bar subtitle
- Style it to be noticeable but not intrusive — small font, rounded corners
- Should be visible at minimum on the main `CombinedView`

**Files to modify**: `Finance/CombinedView.swift`, `Finance/FinanceApp.swift`

**Expected outcome:** Demo mode shows a clear "Demo Mode" label. Production mode shows no banner.

## - [ ] Phase 3: Separate credits/debits in Top 10 Vendors view

**Skills to read**: `swift-swiftui`, `swift-architecture`

Currently `VendorSpending.aggregate(from:)` filters out income transactions but doesn't distinguish between credits and debits within non-income transactions. For checking accounts, deposits show as vendors with negative amounts.

- Add a `TransactionFilter` enum with cases: `.debits`, `.credits`, `.all` — defaulting to `.debits`
- Add a segmented `Picker` in both `VendorSpendingView` and the Top 10 section of `CombinedView`
- Update `VendorSpending.aggregate(from:filter:)` to accept the filter:
  - `.debits`: only transactions where `toBase > 0` (money spent)
  - `.credits`: only transactions where `toBase < 0` (money received, excluding income)
  - `.all`: all non-income transactions (current behavior)
- Both bar chart and pie chart should respect the selected filter

**Files to modify**: `Finance/VendorSpendingView.swift`, `Finance/CombinedView.swift`, `FinancePackage/Sources/services/CoreService/VendorSpending.swift`

**Expected outcome:** Users can toggle between debit vendors, credit vendors, or all. Default shows debits only.

## - [ ] Phase 4: Validation

**Skills to read**: `swift-architecture`

Build the project with `xcodebuild` to verify:
- No compilation errors
- Pie chart compiles without annotation issues
- Demo mode banner code is present and conditional
- Segmented filter control appears in vendor spending views
- All existing functionality still works (no regressions)
