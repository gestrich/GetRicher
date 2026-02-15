## Relevant Skills

No project-level `CLAUDE.md` found — no project-specific skills to reference.

## Background

Bill reviewed the Finance app and identified three UI improvements needed for the chart and transaction views:

1. The pie chart (Spending Distribution) uses `.annotation(position: .overlay)` to place dollar amount labels directly on each sector. When there are many small slices, labels overlap and get clipped. Need to explore Apple Charts API options for better labeling.
2. When running in demo mode (`UserDefaults.standard.object(forKey: "demoMode")`), there's no visual indicator — users could confuse demo data with real data.
3. The "Top 10 Vendors" view in `VendorSpendingView` and `CombinedView` currently shows all non-income transactions. For checking accounts, deposits appear as negative amounts and can show up as vendors. Need a filter to separate credits, debits, and all — defaulting to debits.

The app uses Swift Charts (`SectorMark`, `BarMark`) and follows a 4-layer architecture (App layer views → Features → Services → SDKs).

## Phases

## - [ ] Phase 1: Fix pie chart label clipping

**Files to modify**: `Finance/CombinedView.swift`, `Finance/VendorSpendingView.swift`

The pie chart in `CombinedView` uses `.annotation(position: .overlay)` which causes labels to clip when slices are small. Explore these Apple Charts API alternatives:

- **Option A (preferred):** Remove overlay annotations from `SectorMark` entirely. Use the existing `.foregroundStyle(by:)` legend instead of `.chartLegend(.hidden)`, and show amounts in the legend or a separate list below the chart.
- **Option B:** Use `.annotation(position: .outside)` with leader lines (if available in the Charts API version).
- **Option C:** Only annotate slices above a percentage threshold (e.g., >5% of total), hiding labels for small slices.

Whichever option is chosen, ensure the `VendorSpendingView` pie chart stays consistent (it currently has no annotations, which is fine — just ensure both charts look cohesive).

**Expected outcome:** Pie chart labels are readable regardless of how many vendors exist. No clipping.

## - [ ] Phase 2: Add demo mode indicator label on main screen

**Files to modify**: `Finance/CombinedView.swift`, `Finance/FinanceApp.swift`

When `isDemoMode` is true in `FinanceApp.init()`, the main screen (`CombinedView`) should display a visible "Demo Mode" badge or banner. Implementation approach:

- Pass `isDemoMode` as an environment value or init parameter to `CombinedView`
- Display a persistent banner (e.g., a `Text("Demo Mode")` with a colored background) at the top of the scroll view or in the navigation bar subtitle
- Style it to be noticeable but not intrusive — e.g., yellow/orange background, small font, rounded corners
- The indicator should be visible on all tabs/views if the app has multiple, but at minimum on the main `CombinedView`

**Expected outcome:** When running in demo mode, users immediately see a "Demo Mode" label. In production mode, no banner appears.

## - [ ] Phase 3: Separate credits/debits in Top 10 Vendors view

**Files to modify**: `Finance/VendorSpendingView.swift`, `Finance/CombinedView.swift`, `FinancePackage/Sources/services/CoreService/VendorSpending.swift`

Currently `VendorSpending.aggregate(from:)` filters out `isIncome` transactions but doesn't distinguish between credits (negative `toBase`) and debits (positive `toBase`) within non-income transactions. For checking accounts, deposits show up as vendors with negative amounts.

Implementation:
- Add a `TransactionFilter` enum (or similar) with cases: `.debits`, `.credits`, `.all` — defaulting to `.debits`
- Add a `Picker` (segmented style) in both `VendorSpendingView` and the Top 10 section of `CombinedView` to select the filter
- Update `VendorSpending.aggregate(from:filter:)` to accept the filter:
  - `.debits`: only transactions where `toBase > 0` (money spent)
  - `.credits`: only transactions where `toBase < 0` (money received, excluding income)
  - `.all`: all non-income transactions (current behavior)
- Ensure the bar chart and pie chart both respect the selected filter

**Expected outcome:** Users can toggle between viewing top debit vendors, credit vendors, or all. Default shows debits only, filtering out checking deposits.

## - [ ] Phase 4: Validation

Build the project with `xcodebuild` to ensure no compilation errors. Verify:
- Pie chart compiles without annotation clipping issues
- Demo mode banner appears when `demoMode` is true in UserDefaults
- Segmented filter control appears in vendor spending views
- All existing functionality still works (no regressions)
