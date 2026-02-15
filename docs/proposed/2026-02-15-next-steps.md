# Finance — Next Steps

## Background

Bill reviewed the initial demo mode PR and identified three improvements needed for the Finance app's chart and transaction views.

## Phases

## - [ ] Phase 1: Fix pie chart label clipping

The pie chart labels (amounts) get clipped when the graph is busy with too many labels. Explore Apple Charts API options for alternate labeling strategies (e.g., callouts, legends, or dynamic label hiding for small slices).

## - [ ] Phase 2: Add demo mode indicator label

When running in demo mode, the main screen should display a visible label/badge indicating "Demo Mode" to avoid confusion with real data.

## - [ ] Phase 3: Separate credits/debits in Top 10 Vendors view

In checking accounts, deposit amounts appear as negative values. The "Top 10 Vendors" view currently shows checking deposits mixed in. Add a segmented control or filter to switch between Credits, Debits, and All — with Debits as the default.
