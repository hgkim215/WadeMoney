# WadeMoney Codex UI/UX Handoff

Date last updated: 2026-07-03
Authoring agent: Codex
Intended next agent: Claude or another iOS/SwiftUI agent

## Standing Rule

The user alternates implementation between Codex and Claude. At the end of every meaningful Codex task, update this handoff before the final response so the next agent can continue from the current project state.

The same rule is also recorded in the project root `AGENTS.md`.

## Current Project State

This handoff summarizes the ongoing UI/UX QA and implementation work for WadeMoney. The user is reviewing the app on small iPhone simulator sizes and real devices, with a strong focus on spacing, visual hierarchy, and avoiding awkward or noisy UI.

Important user decisions:

- Removing Siri/Shortcuts/Action Button expense recording is intentional. Do not treat that as a bug.
- Test UI on the smallest available simulator when possible.
- Prefer direct, polished product UI over explanatory text.
- App-wide screen/sheet horizontal spacing should generally use `24pt`.
- Avoid visual clutter such as unnecessary capsules, heavy outlines, or extra decorative button backgrounds.
- Destructive delete actions should show a confirmation reminder before deleting.

## Latest Codex Changes On 2026-07-03

### Legal Documents

Problem:

- Real device failed to open legal links externally with `LSApplicationWorkspaceErrorDomain Code=115` and sandbox-extension errors.

Resolution:

- Replaced external `Link/openURL` handoff with in-app `WKWebView`.
- Settings legal rows now push `LegalDocumentView` inside the app.

Files:

- `WadeMoney/Screens/Settings/ActivityView.swift`
- `WadeMoney/Screens/Settings/SettingsScreen.swift`

Verification:

- Built and ran on iPhone 17e simulator.
- Opened Settings > 이용약관.
- Confirmed Terms page loaded in-app.

### Category Management UX

Problems:

- Category order could be changed before tapping edit.
- Edit and plus buttons initially looked visually clumped or too decorative.
- Delete action was not consistently visible or confirmed.
- Reordering felt stuttery because the view model reloaded the list after every move.

Resolution:

- Reordering is disabled unless edit mode is active.
- Category management now uses a custom top bar for back/title/edit/add to avoid iOS toolbar auto-capsule styling.
- Edit button is icon-only; it changes from `edit` to `check` when active.
- Plus remains icon-only.
- In edit mode, active rows show inline `삭제` or `보관` depending on the actual operation:
  - If a category has never been used, `삭제` hard-deletes it.
  - If a category has transaction history, `보관` archives it.
- Archived rows can show `복원`, and unused archived rows can also show `삭제`.
- All hard-delete paths show a confirmation Alert before deleting.
- Reorder no longer calls `load()` after every move. It moves the local `activeItems` array first and persists the order, reducing visual churn.

Files:

- `WadeMoney/Screens/Categories/CategoryManageScreen.swift`
- `WadeMoney/Screens/Categories/CategoryManageViewModel.swift`
- `WadeMoney/Screens/Categories/CategoryEditSheet.swift`

Verification:

- iPhone 17e simulator:
  - Confirmed edit mode toggles.
  - Confirmed reorder handles appear only in edit mode.
  - Confirmed delete Alert appears with restoration warning.
- Simulator drag automation could not complete because XcodeBuildMCP reported: `FBSimulatorHIDEvent does not support touch move events`.
- Code-level stutter fix is in place by removing immediate reload after move.

### History Search

Problem:

- User wanted to search spending history and inspect matching records.

Resolution:

- Added a search field to History.
- Search filters by memo, category name, income/expense type text, and amount digits.
- Empty result state now shows search-specific copy.
- Added a view model regression test for memo/category/amount search.

Files:

- `WadeMoney/Screens/History/HistoryScreen.swift`
- `WadeMoney/Screens/History/HistoryViewModel.swift`
- `WadeMoneyTests/HistoryViewModelTests.swift`

Verification:

- Added `searchFiltersByMemoCategoryAndAmount`.
- Latest `test_sim`: 117 passed, 0 failed.
- Simulator UI confirmed search field appears and no-result state changes to `검색 결과가 없어요`.
- Korean automated text input is limited by AXe; Korean search behavior is covered in the Swift test.

### History Delete Confirmation

Problem:

- All delete cases should remind the user before deleting.

Resolution:

- History row deletion now uses Alert with restoration warning instead of a looser confirmation dialog.

Files:

- `WadeMoney/Screens/History/HistoryScreen.swift`

Verification:

- Covered by build/test.

## Earlier UI/UX Decisions Still Relevant

### Dashboard Empty States

- Avoid ambiguous `₩0`, `총지출 0`, and empty donut states.
- Use action-oriented empty copy such as `첫 소비를 기록해보세요`.

Files:

- `WadeMoney/Screens/Dashboard/DashboardViewModel.swift`
- `WadeMoney/Screens/Dashboard/DashboardComponents.swift`

### Dashboard Layout Rhythm

- Three main `한눈에` blocks use a common generous height.
- Top content spacing was reduced after the user said the title sat too low.
- Dashboard bottom spacing accounts for the custom tab bar.

Files:

- `WadeMoney/DesignSystem/WadeMetrics.swift`
- `WadeMoney/Screens/Dashboard/DashboardScreen.swift`
- `WadeMoney/Screens/Dashboard/DashboardComponents.swift`

### Dashboard Donut

- Donut sizing should be judged by the visual outer edge, not the inner stroke or nominal frame.
- Category donut outer margin should visually align with the budget empty-state circle.

File:

- `WadeMoney/Screens/Dashboard/DashboardComponents.swift`

### Period Segmented Control

- Day/month/year segmented control needs a visible but tasteful border.
- Avoid overly harsh borders; the user rejected a version that looked technically clearer but aesthetically awkward.

Files:

- `WadeMoney/Screens/Dashboard/DashboardComponents.swift`
- `WadeMoney/Screens/Dashboard/DashboardScreen.swift`

### Bottom Tab Bar And Toast

- Custom tab bar was reduced in height and bottom offset.
- Stats tab is intentionally unavailable for now; tapping it shows a toast.
- Toast should appear just above the tab bar and move subtly, not rise from too low.

File:

- `WadeMoney/Screens/RootTabView.swift`

### Quick Add Category Selection

- Nested picker sheet was rejected as poor UX.
- Current direction is an inline one-row horizontal category rail with search.
- Search empty state should stay compact and not create a large blank gap.

File:

- `WadeMoney/Screens/QuickAdd/QuickAddSheet.swift`

### Global Sheet And Screen Spacing

- Sheet top and horizontal padding generally use shared `WadeSpacing` values.
- Bottom sheet padding should leave breathing room above the home indicator / bottom safe area.

Files:

- `WadeMoney/DesignSystem/WadeMetrics.swift`
- `WadeMoney/Screens/Categories/CategoryEditSheet.swift`
- `WadeMoney/Screens/Settings/BudgetSheet.swift`
- `WadeMoney/Screens/Settings/MonthStartDaySheet.swift`
- `WadeMoney/Screens/QuickAdd/QuickAddSheet.swift`

## Current Verification Snapshot

Latest verified commands/results from Codex:

- `mcp__xcodebuildmcp.test_sim({"progress": false})`
  - Result: 117 passed, 0 failed, 0 skipped.
- `mcp__xcodebuildmcp.build_run_sim({})`
  - Result: succeeded on iPhone 17e simulator.
- `git diff --check`
  - Result: passed.
- `mcp__xcodebuildmcp.stop_app_sim({})`
  - Result: succeeded after UI checks.

UI checks performed:

- History search field appears.
- History search no-result state appears.
- Category edit mode toggles.
- Category delete confirmation Alert appears.
- Category reorder handles appear only in edit mode.
- Legal document page loads in-app on simulator.

## Known Constraints And Notes

- CodeGraph is not initialized in this project. Tool response: `CodeGraph not initialized in /Users/mac/Documents/Projects/WadeMoney`.
- XcodeBuildMCP text input cannot reliably type Korean through AXe. Korean search behavior is covered by unit tests.
- XcodeBuildMCP drag automation failed for reorder handles due to simulator HID limitation, so reorder smoothness should be manually checked on simulator or device.
- There are multiple uncommitted UI changes across the project; do not assume `main` is clean.
- The user is sensitive to visual hierarchy. If a control starts looking like a floating decoration, simplify it.

## Files Currently Modified In This UI/UX Pass

- `AGENTS.md`
- `WadeMoney/DesignSystem/WadeMetrics.swift`
- `WadeMoney/Screens/Categories/CategoryEditSheet.swift`
- `WadeMoney/Screens/Categories/CategoryManageScreen.swift`
- `WadeMoney/Screens/Categories/CategoryManageViewModel.swift`
- `WadeMoney/Screens/Dashboard/DashboardComponents.swift`
- `WadeMoney/Screens/Dashboard/DashboardScreen.swift`
- `WadeMoney/Screens/History/HistoryScreen.swift`
- `WadeMoney/Screens/History/HistoryViewModel.swift`
- `WadeMoney/Screens/QuickAdd/QuickAddSheet.swift`
- `WadeMoney/Screens/RootTabView.swift`
- `WadeMoney/Screens/Settings/ActivityView.swift`
- `WadeMoney/Screens/Settings/BudgetSheet.swift`
- `WadeMoney/Screens/Settings/MonthStartDaySheet.swift`
- `WadeMoney/Screens/Settings/SettingsScreen.swift`
- `WadeMoneyTests/HistoryViewModelTests.swift`

## Suggested Next Checks For Claude

1. Manually test category reorder on a real device or Simulator with pointer/touch interaction because automation could not drag the handle.
2. Test History search with real Korean input on device: memo, category, and amount.
3. Re-check category management top bar on the smallest available simulator for tap comfort and visual balance.
4. Re-check destructive action copy if categories with transaction history show `보관`, not `삭제`.
5. Re-run `test_sim` after any follow-up UI changes.

## Suggested Commit Message

`polish(ui): refine category management and history search`
