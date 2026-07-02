# WadeMoney Codex UI/UX Handoff

Date: 2026-07-02
Authoring agent: Codex
Intended next agent: Claude or another iOS/SwiftUI agent

## Purpose

This document summarizes the UI/UX review and implementation work completed in Codex so the next agent can continue without replaying the full conversation.

The user asked Codex to review the current iOS project against the design folder, run the app end-to-end, and improve awkward UI/UX. During iteration, the user explicitly confirmed that removing Siri/Shortcuts/Action Button expense recording is intentional and should not be treated as a bug.

## Skills And Tools Used

- Superpowers: requesting-code-review, verification-before-completion, finishing-a-development-branch guidance.
- iOS skills: SwiftUI UI patterns and XcodeBuildMCP simulator workflows.
- Lazyweb: product UI references for dashboard cards, category selection, empty states, and segmented controls.
- XcodeBuildMCP: simulator tests, build/run, UI snapshots, screenshots, taps, swipes.

CodeGraph was requested by project instructions, but this project did not have CodeGraph initialized at the time. The tool returned: `CodeGraph not initialized in /Users/mac/Documents/Projects/WadeMoney`.

## Main UX Decisions

### Dashboard Empty States

- Avoid showing ambiguous `₩0`, `총지출 0`, or empty donut states when there is no spending.
- The dashboard now distinguishes whether the current period has any expenses via `DashboardDisplay.hasExpense`.
- Empty dashboard messaging uses user-action copy such as `첫 소비를 기록해보세요` and `기록 후 비중이 보여요`.

Files:
- `WadeMoney/Screens/Dashboard/DashboardViewModel.swift`
- `WadeMoney/Screens/Dashboard/DashboardComponents.swift`

### Dashboard Layout Rhythm

- The three main "한눈에" blocks now share a generous common minimum height through `WadeSpacing.dashboardBlockHeight`.
- Dashboard-only bottom spacing was split into `WadeSpacing.dashboardContentBottom` so the last card is not trapped behind the custom tab bar.
- Global horizontal spacing is now `24pt`.
- Top content spacing was reduced after user feedback because the title sat too low under the Dynamic Island area.

Files:
- `WadeMoney/DesignSystem/WadeMetrics.swift`
- `WadeMoney/Screens/Dashboard/DashboardScreen.swift`
- `WadeMoney/Screens/Dashboard/DashboardComponents.swift`

### Dashboard Donut Sizing

- The category donut was too large and visually cramped.
- The donut now measures from the visual outer edge, not merely the SwiftUI frame or stroke center path.
- `DonutRing` takes `outerSize` and `lineWidth`; the circle path is `outerSize - lineWidth`, so the drawn stroke's outer edge matches the intended outer size.
- This was done to align the donut's external margin with the `BudgetUnsetBadge` circle.

File:
- `WadeMoney/Screens/Dashboard/DashboardComponents.swift`

### Period Segmented Control

- The day/month/year segmented control looked like a floating white area because it had no border.
- Added a subtle 1pt outer border and a subtle selected-segment border using existing `WadeColors.track`.

File:
- `WadeMoney/Screens/Dashboard/DashboardComponents.swift`

### Bottom Tab Bar

- The custom tab bar was visually too tall and floated too far from the bottom edge.
- Reduced tab bar vertical padding, icon size, label size, FAB size, FAB vertical offset, and shadow.
- Kept the center add action prominent, but less bulky.

File:
- `WadeMoney/Screens/RootTabView.swift`

### Quick Add Category Selection

- The original category grid worked with two rows, but would scale poorly if users add or edit many categories.
- A nested `.large` picker sheet was considered and rejected during iteration as poor UX.
- Final direction: inline one-row horizontal category rail with search toggle.
- Category chips use fixed calculated widths so four chips fit across the available width; additional categories are selected by horizontal scrolling.
- Search empty state is compact and no longer creates a large vertical gap.
- Added progress chips for the add flow: amount, category, save.

File:
- `WadeMoney/Screens/QuickAdd/QuickAddSheet.swift`

### Global Sheet And Screen Spacing

- Several sheets were moved to the common `WadeSpacing.screenH` horizontal padding and slightly larger bottom padding.
- This was done to make spacing feel consistent after the app-wide `24pt` decision.

Files:
- `WadeMoney/Screens/Categories/CategoryEditSheet.swift`
- `WadeMoney/Screens/Settings/BudgetSheet.swift`
- `WadeMoney/Screens/Settings/MonthStartDaySheet.swift`
- `WadeMoney/Screens/QuickAdd/QuickAddSheet.swift`

### Secondary UI Polish

- History list cards and Settings sections now use the shared list shadow.
- Settings iCloud row now shows a non-action informational subtitle and no longer behaves like a disabled button row.

Files:
- `WadeMoney/Screens/History/HistoryScreen.swift`
- `WadeMoney/Screens/Settings/SettingsScreen.swift`

## Verification Performed

Repeated during the UI iteration:

- `mcp__xcodebuildmcp.test_sim` on iPhone 17 Pro simulator.
- Latest observed test result before handoff: 96 passed, 0 failed.
- `git diff --check`.
- `mcp__xcodebuildmcp.build_run_sim`.
- Simulator screenshots and UI snapshots for:
  - Dashboard first viewport.
  - Dashboard after scroll.
  - Quick Add category search empty state.
  - Dashboard segmented control after border update.

## Known Constraints And Notes

- The XcodeBuildMCP text input tool could not reliably type Korean into the simulator during search testing; it produced Korean keyboard characters when given latin input. The empty-result layout bug was still verified visually by typing a non-matching query.
- Lazyweb returned useful references for several searches, but one dashboard-related search timed out. Work proceeded from simulator evidence and local UI patterns.
- The design remains intentionally soft and card-based. Avoid introducing heavy outlines or high-contrast borders unless the user asks; recent direction favored subtle `track` strokes.
- The user is sensitive to spacing, especially:
  - Title-to-top safe-area distance.
  - Bottom tab bar height and bottom offset.
  - Donut/card internal margins.
  - Category picker breathing room.

## Suggested Next Checks For Claude

1. Run the app on at least one smaller simulator if available and inspect the one-row category rail.
2. Re-check Dashboard in empty-data and non-empty-data states.
3. Re-check Settings rows after the row helper change to ensure disabled informational rows do not feel tappable.
4. Consider adding UI tests or snapshot-style checks for the Quick Add category search empty state and Dashboard empty state if the project adopts UI testing.

## Current Implementation Summary

This implementation is intended as one coherent UI/UX polish change set. It touches these files:

- `WadeMoney/DesignSystem/WadeMetrics.swift`
- `WadeMoney/Screens/Categories/CategoryEditSheet.swift`
- `WadeMoney/Screens/Dashboard/DashboardComponents.swift`
- `WadeMoney/Screens/Dashboard/DashboardScreen.swift`
- `WadeMoney/Screens/Dashboard/DashboardViewModel.swift`
- `WadeMoney/Screens/History/HistoryScreen.swift`
- `WadeMoney/Screens/QuickAdd/QuickAddSheet.swift`
- `WadeMoney/Screens/RootTabView.swift`
- `WadeMoney/Screens/Settings/BudgetSheet.swift`
- `WadeMoney/Screens/Settings/MonthStartDaySheet.swift`
- `WadeMoney/Screens/Settings/SettingsScreen.swift`

The intended commit message is:

`polish(ui): refine dashboard and quick-add UX`
