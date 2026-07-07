# WadeMoney Codex UI/UX Handoff

Date last updated: 2026-07-03
Authoring agent: Codex
Intended next agent: Claude or another iOS/SwiftUI agent

## Standing Rule

The user alternates implementation between Codex and Claude. At the end of every meaningful Codex task, update this handoff before the final response so the next agent can continue from the current project state.

The same rule is also recorded in the project root `AGENTS.md`.

2026-07-03 memory refresh:

- The user explicitly reaffirmed: "현재까지 진행된 내용 다시 업데이트 해서 기억해".
- Treat this handoff as the durable shared memory between Codex and Claude.
- If a future task changes code, UI decisions, verification status, or known risks, update this file again before the final response.

## Current Project State

This handoff summarizes the ongoing UI/UX QA and implementation work for WadeMoney. The user is reviewing the app on small iPhone simulator sizes and real devices, with a strong focus on spacing, visual hierarchy, and avoiding awkward or noisy UI.

Important user decisions:

- Removing Siri/Shortcuts/Action Button expense recording is intentional. Do not treat that as a bug.
- Test UI on the smallest available simulator when possible.
- Prefer direct, polished product UI over explanatory text.
- App-wide screen/sheet horizontal spacing should generally use `24pt`.
- Avoid visual clutter such as unnecessary capsules, heavy outlines, or extra decorative button backgrounds.
- Destructive delete actions should show a confirmation reminder before deleting.
- Category management should feel native, quiet, and not "밤티" or visually gimmicky; avoid moving primary controls into awkward section-header positions just to dodge toolbar styling.

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
- Handoff refresh after the user asked to remember current progress:
  - No app code changed for this refresh.
  - Only this handoff memory section was updated.

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

## 2026-07-03 Codex Brainstorm: Special Expense / Budget Exclusion

Context:

- User asked whether unusually large or meaningful expenses, such as a first-paycheck gift to parents, should be recordable without counting against the monthly budget.
- User explicitly requested Superpowers brainstorming, so Codex paused implementation and explored the current data/budget architecture first.
- User agreed to review the flow with a browser mockup.

Code context found:

- `TransactionModel` and `TransactionRecord` currently have no budget-exclusion or special-expense flag.
- `TransactionKind` only distinguishes `expense` and `income`.
- `LedgerRepository.dashboardSummary` uses `Aggregator.totalExpense` and category totals as the shared source for dashboard budget, donut, trend, AI report, and widgets.
- Therefore a real implementation would need a clear product decision before coding: whether special expenses are excluded only from budget math, or also separated from dashboard total spending, category ratio, AI report, trend, widgets, and history filters.

Mockup created:

- `docs/superpowers/mockups/special-expense-flow.html`

Mockup options:

- A. Recommended: keep normal expense flow, add an `예산에서 제외` toggle inside the quick-add sheet as a secondary option.
- B. Show special expenses mainly in History with `예산 제외` label and filters.
- C. Split Dashboard into `예산 반영 지출`, `전체 지출`, and `예산 제외` summaries.

Current recommendation:

- Start with option A as the primary entry flow.
- Also add a small History label/filter so users can find excluded expenses later.
- Avoid making Dashboard too heavy at first; dashboard can optionally show a subtle `예산 제외 N원` note only when excluded expenses exist.

Verification performed this turn:

- No app code was changed.
- Created standalone HTML mockup only.
- Local static server started from project root: `python3 -m http.server 8765 --bind 127.0.0.1`.
- Mockup URL: `http://127.0.0.1:8765/docs/superpowers/mockups/special-expense-flow.html`.

Open question for user:

- Should excluded expenses remain visible in total/history/category stats while only being removed from budget consumed/remaining, or should they be fully separated from all spending analytics?

## 2026-07-03 User Decision: Special Expense UX

User decision:

- Proceed with option A.
- Add `예산에서 제외` as a secondary toggle in the expense entry/edit sheet.
- Do not add History filters for excluded expenses.
- Show only an `예산 제외` label on the relevant transaction rows.
- Even when the `예산 제외` label is shown, every History transaction card must preserve the same height as normal rows. Do not let the badge add a new line or expand the card.

Files changed this turn:

- `docs/superpowers/mockups/special-expense-flow.html`
- `docs/superpowers/specs/2026-07-03-special-expense-budget-exclusion-design.md`
- `docs/superpowers/plans/2026-07-02-codex-ui-ux-handoff.md`

Verification performed this turn:

- No app code changed.
- No build or test run needed for this design-only update.
- Existing local mockup server remains available at `http://127.0.0.1:8765/docs/superpowers/mockups/special-expense-flow.html`; refresh the page to see the updated no-filter version.

Implementation caution:

- Dashboard decision resolved by user:
  - Dashboard main block should still show this month's real total spending, including special excluded expenses.
  - Only budget consumed percentage and remaining budget should exclude special expenses.
  - If space allows, show a secondary line such as `예산 반영 ₩680,000 · 제외 ₩500,000` so users understand why budget progress differs from total spending.

## 2026-07-03 Codex Implementation: Special Expense Budget Exclusion

Branch:

- `codex/special-expense-budget-exclusion`

What changed:

- Added `isExcludedFromBudget` to core transaction records and SwiftData transaction models.
- Added `Aggregator.budgetedExpense` while keeping `Aggregator.totalExpense` as real total spending.
- Updated repository create/update/mapping so excluded expenses round-trip through persistence.
- Dashboard summary now keeps:
  - `totalExpense`: real spending, including excluded expenses.
  - `budgetedExpense`: spending counted against budget.
  - `excludedExpense`: total excluded spending.
- Dashboard remaining budget, consumed percent, and budget projection use `budgetedExpense`.
- Dashboard main total text still uses real total spending.
- Dashboard budget line shows `예산 반영 ... · 제외 ...` when excluded spending exists.
- QuickAdd expense sheet now has an expense-only `예산에서 제외` toggle.
- Switching QuickAdd to income clears budget exclusion and income saves with exclusion disabled.
- History rows show an inline `예산 제외` label for excluded expenses.
- History filters were intentionally not added, per user decision.
- History row height is kept stable with an inline badge and fixed minimum row height.

Files touched by this feature:

- `WadeMoney/Mapping/ModelMapping.swift`
- `WadeMoney/Models/TransactionModel.swift`
- `WadeMoney/Screens/Dashboard/DashboardComponents.swift`
- `WadeMoney/Screens/Dashboard/DashboardViewModel.swift`
- `WadeMoney/Screens/History/HistoryScreen.swift`
- `WadeMoney/Screens/History/HistoryViewModel.swift`
- `WadeMoney/Screens/QuickAdd/QuickAddSheet.swift`
- `WadeMoney/Screens/QuickAdd/QuickAddViewModel.swift`
- `WadeMoney/Stores/LedgerRepository.swift`
- `WadeMoneyCore/Sources/WadeMoneyCore/Aggregator.swift`
- `WadeMoneyCore/Sources/WadeMoneyCore/Domain.swift`
- `WadeMoneyCore/Tests/WadeMoneyCoreTests/AggregatorTests.swift`
- `WadeMoneyTests/DashboardViewModelTests.swift`
- `WadeMoneyTests/HistoryViewModelTests.swift`
- `WadeMoneyTests/LedgerRepositoryTests.swift`
- `WadeMoneyTests/ModelMappingTests.swift`
- `WadeMoneyTests/QuickAddEditTests.swift`
- `WadeMoneyTests/QuickAddViewModelTests.swift`
- `docs/superpowers/mockups/special-expense-flow.html`
- `docs/superpowers/plans/2026-07-03-special-expense-budget-exclusion-implementation.md`
- `docs/superpowers/specs/2026-07-03-special-expense-budget-exclusion-design.md`

Verification performed:

- RED/GREEN TDD:
  - `swift test --package-path WadeMoneyCore --filter AggregatorTests`
    - RED: failed because `isExcludedFromBudget` and `budgetedExpense` did not exist.
    - GREEN: passed 6 Aggregator tests.
  - `test_sim -only-testing:WadeMoneyTests/ModelMappingTests -only-testing:WadeMoneyTests/LedgerRepositoryTests`
    - RED: failed because repository/model fields did not exist.
    - GREEN: passed 12 tests.
  - `test_sim -only-testing:WadeMoneyTests/QuickAddViewModelTests -only-testing:WadeMoneyTests/QuickAddEditTests`
    - RED: failed because `QuickAddViewModel.isExcludedFromBudget` did not exist.
    - GREEN: passed 9 tests.
  - `test_sim -only-testing:WadeMoneyTests/HistoryViewModelTests`
    - RED: failed because row label flag did not exist.
    - GREEN: passed 6 tests.
  - `test_sim -only-testing:WadeMoneyTests/DashboardViewModelTests`
    - RED: failed because `budgetBasisText` did not exist.
    - GREEN: passed 3 tests.
- Full verification:
  - `swift test --package-path WadeMoneyCore`: passed 37 tests.
  - `git diff --check`: passed.
  - XcodeBuildMCP `test_sim`: passed 141 tests on iPhone 17e simulator.
  - XcodeBuildMCP `build_run_sim`: succeeded on iPhone 17e simulator.
  - Screenshot check on iPhone 17e Dashboard succeeded; app launched and fit the screen.

Known limitations / follow-up:

- XcodeBuildMCP runtime UI snapshot returned no tappable accessibility targets for the running app in this session, so Codex could not automatically tap `+` and screenshot the QuickAdd sheet. Manual check on Simulator/device is still recommended for the new toggle row.
- Existing uncommitted Splash/Mascot changes were present before this feature implementation and were not part of the special-expense work:
  - `WadeMoney/DesignSystem/MascotView.swift`
  - `WadeMoney/Screens/Splash/SplashScreen.swift`
  - `WadeMoney/Screens/Splash/SplashTimeline.swift`
  - `WadeMoneyTests/SplashTests.swift`

## 2026-07-03 Codex UI Polish: Category Donut Center Text

User feedback:

- In Dashboard > `카테고리 비중`, the donut center text `최다 지출 / 식비 / 100%` looked visually awkward and did not add meaningful information because the legend already shows category and percent.
- After trying a lighter icon-only center, the user decided the text direction was still clearer as long as the donut center is not crowded.

What changed:

- Restored compact top-category text in `DonutRing`: `최다 지출` plus the category name.
- Removed the redundant percent from the donut center so the legend remains the only percent display.
- Removed the temporary center icon badge and its dashboard-only `iconName` view-model field.
- Added a subtle track ring behind category arcs so the donut still has stable visual structure.
- Kept the center text constrained to the inner donut hole with a smaller label, one-line category name, and scaling fallback to avoid filling the inner space too tightly.

Files touched:

- `WadeMoney/Screens/Dashboard/DashboardComponents.swift`
- `WadeMoney/Screens/Dashboard/DashboardViewModel.swift`
- `docs/superpowers/plans/2026-07-02-codex-ui-ux-handoff.md`

Verification:

- Lazyweb reference search for mobile finance category/donut patterns completed before changing UI.
- `git diff --check -- WadeMoney/Screens/Dashboard/DashboardViewModel.swift WadeMoney/Screens/Dashboard/DashboardComponents.swift`: passed.
- `swift test --package-path WadeMoneyCore`: passed 37 tests.
- XcodeBuildMCP `test_sim`: passed 141 tests.
- XcodeBuildMCP `build_run_sim`: succeeded on iPhone 17e simulator.
- Screenshot check on iPhone 17e Dashboard succeeded after re-launch: `카테고리 비중` shows compact `최다 지출 / 식비` center text, no center percent, and the block fits the screen.

## 2026-07-03 Codex UI Polish: Splash Design Document Alignment

User request:

- Analyze `docs/design/app-design-specification-analysis` and improve the partially implemented Splash page against the splash design document.
- Follow-up feedback: splash text was too large, so make the text smaller.

Design source analyzed:

- Primary design file per bundle README: `docs/design/app-design-specification-analysis/project/WadeMoney 스플래시.dc.html`.
- Key design intent found in the document:
  - Warm radial cream background.
  - Soft green brand glow behind the mascot.
  - Pig + donut mascot animation remains the hero.
  - `WadeMoney` wordmark and Korean tagline appear after the bite/chew moment.
  - Small three-dot loader sits near the bottom.

What changed:

- Kept the existing SwiftUI mascot/donut animation structure.
- Added a Splash-specific radial background matching the design document more closely than the plain app background.
- Added a soft primary-green radial glow behind the mascot.
- Added `WadeMoney` wordmark, Korean tagline, and small animated loader dots.
- Sequenced wordmark/tagline reveal into the existing bite/chew timeline.
- Increased standard splash total duration from 2.00s to 2.76s so the brand lockup has a readable hold.
- After user feedback that Splash felt too long, shortened standard splash duration from 2.76s to 1.86s, keeping it within the requested 1.5-2.0s range.
- Reduced text size after user feedback:
  - Wordmark: 47pt -> 34pt.
  - Tagline: 17.5pt -> 13.5pt.

Files touched:

- `WadeMoney/Screens/Splash/SplashScreen.swift`
- `WadeMoney/Screens/Splash/SplashTimeline.swift`
- `WadeMoneyTests/SplashTests.swift`
- `docs/superpowers/plans/2026-07-02-codex-ui-ux-handoff.md`

Verification:

- Lazyweb mobile splash screen reference search completed before UI changes. Result pattern supported minimal centered brand/mascot splash screens with limited copy.
- `git diff --check -- WadeMoney/Screens/Splash/SplashScreen.swift WadeMoney/Screens/Splash/SplashTimeline.swift WadeMoneyTests/SplashTests.swift`: passed.
- `swift test --package-path WadeMoneyCore`: passed 37 tests.
- 2026-07-07 after shortening duration:
  - `git diff --check -- WadeMoney/Screens/Splash/SplashTimeline.swift WadeMoneyTests/SplashTests.swift`: passed.
  - `swift test --package-path WadeMoneyCore`: passed 37 tests.
  - XcodeBuildMCP `build_run_sim`: succeeded on iPhone 17e simulator.
  - XcodeBuildMCP `test_sim`: passed 141 tests.

Known limitations / follow-up:

- XcodeBuildMCP screenshots repeatedly captured the app after it had already transitioned to Dashboard, so Codex could not capture the transient Splash frame through MCP in this session.
- Manual Simulator/device visual check is still recommended for final splash animation timing and text scale, especially because this screen is intentionally short-lived.
- XcodeBuildMCP build/test currently reports an unrelated warning: app extension `CFBundleVersion` is `1` while the containing app is `2`.

### 2026-07-07 Splash Mouth Animation Polish

User feedback:

- Splash mascot mouth animation felt unnatural.
- User was open to reducing the number of chew beats if the mouth movement became more natural.

Root cause / design analysis:

- The mouth was opening by scaling the whole mouth shape vertically, which made it feel like a mechanical flap rather than a hinged mouth.
- The shortened 1.86s splash timeline still had three chew beats, making the mouth motion feel busy and compressed.

What changed:

- Updated `MascotView` mouth geometry so the top edge stays fixed and the mouth opens downward by changing height/center position.
- Reduced chew beats from 3 to 2.
- Reduced chew mouth-open amplitude from `0.55` to `0.32`.
- Reduced the pre-bite windup mouth-open value from `1.0` to `0.82`.
- Made chew timing asymmetric:
  - quicker open beat,
  - slower close beat,
  - one blink during the chew instead of two.
- Kept total splash duration unchanged at 1.86s.

Files touched:

- `WadeMoney/DesignSystem/MascotView.swift`
- `WadeMoney/Screens/Splash/SplashScreen.swift`
- `docs/superpowers/plans/2026-07-02-codex-ui-ux-handoff.md`

Verification:

- Lazyweb quick reference search for mobile splash animation completed; current task stayed scoped to micro-animation polish.
- `git diff --check -- WadeMoney/DesignSystem/MascotView.swift WadeMoney/Screens/Splash/SplashScreen.swift`: passed.
- `swift test --package-path WadeMoneyCore`: passed 37 tests.
- XcodeBuildMCP `build_run_sim`: succeeded on iPhone 17e simulator.
- XcodeBuildMCP `test_sim`: passed 141 tests.

Known limitations / follow-up:

- MCP screenshot capture still tends to miss the transient splash frame and land on Dashboard, so manual Simulator/device viewing is recommended for final subjective motion approval.
- Existing unrelated warnings remain:
  - `SentenceHighlighter.swift` uses deprecated `Text + Text` composition on iOS 26.
  - App extension `CFBundleVersion` is `1` while containing app is `2`.

## 2026-07-07 Codex Main Push Preparation

User request:

- Push the completed Codex work to `main`.

What changed in this turn:

- Created commit `f9c4206` on `codex/special-expense-budget-exclusion` with the selected app/test/docs changes.
- Created a temporary clean `main` worktree at `/tmp/wademoney-main-push-1783389854`.
- Cherry-picked the feature commit onto local `main`, producing main commit `70af140`.
- Excluded the dirty `docs/design/app-design-specification-analysis` bundle changes from staging/push because they were not Codex-authored app changes in this turn.
- Generated `WadeMoney.xcodeproj` in the temporary worktree with `xcodegen generate` because `.xcodeproj` is generated from `project.yml`.

Files included in the main push scope:

- Budget-excluded expense domain/model/repository/dashboard/history/quick-add changes.
- Dashboard category donut center text polish.
- Splash screen design alignment, duration reduction, text-size reduction, and mouth animation polish.
- Related tests.
- Superpowers handoff/spec/plan/mockup docs.

Verification on the merged main result:

- `git diff --check HEAD~1..HEAD`: passed.
- `swift test --package-path WadeMoneyCore`: passed 37 tests.
- `xcodegen generate`: succeeded in the temporary main worktree.
- XcodeBuildMCP `build_run_sim`: succeeded on iPhone 17e simulator.
- XcodeBuildMCP `test_sim`: passed 141 tests.

Known limitations / follow-up:

- XcodeBuildMCP reported existing warnings unrelated to this push:
  - `SentenceHighlighter.swift` uses deprecated `Text + Text` composition on iOS 26.
  - `DesignTokenTests.swift` calls main actor-isolated `symbolFont(size:filled:)` from a synchronous nonisolated context.
- The original working tree still has unstaged/untracked `docs/design/app-design-specification-analysis` bundle changes that were intentionally not included.
