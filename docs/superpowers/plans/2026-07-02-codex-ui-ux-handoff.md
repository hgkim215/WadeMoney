# WadeMoney Codex UI/UX Handoff

Date last updated: 2026-07-07
Authoring agent: Claude and Codex have both appended sections concurrently this session; see each dated heading for who authored it. Latest entries: Claude's QuickAdd UX pass, then Codex's App Update Prompt + Feedback Mail work and DEBUG update-prompt preview.
Intended next agent: Codex or another iOS/SwiftUI agent

Note: this file was edited by both agents across several turns without being committed alongside the code commits that referenced it — commits `abc5e8a` through `4b5edca` all list this file under "Files touched" but none of them actually included it (verified via `git show --stat <sha> -- docs/superpowers/plans/2026-07-02-codex-ui-ux-handoff.md`, which returned empty for each). Claude committed the accumulated content on 2026-07-07 so it stops floating uncommitted. If you're a fresh agent, trust `git log -- docs/superpowers/plans/2026-07-02-codex-ui-ux-handoff.md` over any individual commit's own claim about touching this file.

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

## 2026-07-07 Claude Implementation: AI Report Visual Polish (SentenceHighlighter)

User request:

- Make the AI Report screen (`AIReportScreen`) visually match a provided mockup with number-highlighted sentences and a polished 4-card layout.
- Ran full Superpowers flow: brainstorming -> writing-plans -> subagent-driven-development.

User correction during brainstorming:

- Verified (no code change needed): when Foundation Models AI is unavailable on-device, the AI Report entry point is already fully hidden, not degraded. This was already correct in `AIAvailabilityChecking` usage across `AIReportViewModel` and `DashboardViewModel`.

What changed:

- New `SentenceHighlighter.swift`: pure-Swift regex-based number highlighting (percentages, won amounts) for AI-generated sentences, clause-boundary classification (increase/decrease/neutral) based on nearby Korean keywords, `styledText(_:font:scheme:)` SwiftUI `Text` renderer.
- `AIReportScreen.summaryCard` and `tipCard` now render through `SentenceHighlighter.styledText` instead of plain `Text`.
- `tipCard` gained a `.redacted(reason: .placeholder)` loading skeleton shown while the AI tip sentence is still narrating.

Files touched:

- `WadeMoney/DesignSystem/SentenceHighlighter.swift` (new)
- `WadeMoney/Screens/Report/AIReportScreen.swift`
- `WadeMoneyTests/SentenceHighlighterTests.swift` (new, 8 tests)
- `docs/superpowers/specs/2026-07-03-ai-report-visual-polish-design.md`
- `docs/superpowers/plans/2026-07-03-ai-report-visual-polish.md`

Incident during execution (transparently surfaced to the user, not silently fixed):

- A concurrent Codex CLI session checked out `codex/special-expense-budget-exclusion` in the same shared working directory while Claude's Task 2 implementer subagent was running, causing its commit to land on the wrong branch instead of `main`. Diagnosed via `git reflog`. Fixed by verifying the commit's diff touched only its 2 intended files, then using an isolated `git worktree add ... main` to cherry-pick the commit onto `main` cleanly (new SHA), running a full clean build+test there, and removing the worktree — without touching the shared working directory's checkout or Codex's uncommitted files. Both Codex and Claude have now independently used this "isolated worktree cherry-pick" technique to land work on `main` from a shared/dirty working tree.

Verification performed:

- Task-level and whole-branch code review all "Approved" / "Ready to merge: Yes".
- Clean build+test in isolated worktree: 132/132 passed (124 pre-existing + 8 new `SentenceHighlighterTests`).
- Simulator screenshots in light and dark mode confirmed number highlighting and tip-card skeleton render correctly.

Known limitations / follow-up:

- `SentenceHighlighter.swift` uses deprecated `Text + Text` composition on iOS 26 (build warning, not error) — worth fixing next time this file is touched.

## 2026-07-07 Claude: App Store Connect Metadata + Support Page Contact

User request:

- Draft App Store Connect fields (설명/키워드/지원 URL/마케팅 URL/버전/저작권, later 이름/부제) based on actual project research, not placeholders.

What changed:

- Drafted description, keywords, version confirmation, and copyright based on README/project.yml/existing gh-pages legal docs.
- Support/marketing URL was `https://hgkim215.github.io/WadeMoney/` but had no contact mechanism. With explicit user permission (publishing to a public page), added a `mailto:hgkim215@gmail.com` "문의하기" link to that page's `index.html` on the orphan `gh-pages` branch.
- Combined two subtitle drafts per user request into one: `3초 기록 · 온디바이스 AI 가계부 리포트` (24 chars).

Files touched:

- `gh-pages` branch `index.html` only (isolated worktree `/tmp/wade-ghpages`, committed and pushed to `origin/gh-pages`). No `main`-branch app code changed.

Known limitations / follow-up:

- Whether the App Store Connect app record itself now exists (unblocking the earlier TestFlight `IDEDistributionAppRecordProviderError`) was not independently re-verified after the user started filling in these fields — check before assuming the original TestFlight blocker is resolved.

## 2026-07-07 Claude: QuickAdd Sheet UX Pass (commit `6fedc7b`)

User request:

- The budget-input area in QuickAdd was taking so much vertical space that the "저장하기" save button was pushed below the fold, requiring a scroll. Fix that, and report any other UX issues found in the sheet.
- Follow-up: user approved all 5 reported issues and asked to proceed. Then two more rounds of visual feedback on the resulting layout.

What changed (in order of iteration):

1. Merged the `예산에서 제외` budget-exclusion row (previously a full-width card with icon + 2 lines of text + switch) into the date row as a compact toggle, so the save button is visible without scrolling on first view.
2. Removed the `stepChips` "금액 → 카테고리 → 저장" progress indicator entirely — low information value, always took ~40pt of height. (This was a plan-mandated feature from the original 2026-07-01 design spec; user explicitly approved removing it, so the spec doc `2026-07-01-wademoney-design-system.md` §5.6 was updated to match.)
3. Category chip row now widens chips slightly (divisor 3.6 instead of 4) when there are more than 4 categories, so the 5th chip peeks partially cut off at the trailing edge — signals horizontal scrollability that was previously invisible.
4. Reduced the memo card's vertical padding for de-emphasis (13→10), since it was visually as heavy as required fields despite being optional at the time.
5. Then reversed part of #4 per user feedback: memo is actually important ("어떤 내역인지 작성해야 하는 부분"), so it was made **required** for new entries (`QuickAddViewModel.canSave` now also requires non-empty memo, but only when `!isEditing` — editing existing memo-less records still saves normally, so the 3 existing edit tests with `memo: nil` did not need to change). Memo field padding was restored/increased (13 vertical) and a leading `edit_note` icon was added; placeholder changed from "메모 (선택)" to "메모 (어떤 내역인가요?)".
6. Budget-exclusion toggle was originally a lone icon (hard for first-time users to parse) — added a "제외" text label next to the icon inside a capsule (bordered when off, filled `primarysoft` when on).
7. Date row grouping fix per user feedback (screenshot of "날짜 ... 2026.7.7. ... 제외" reading as three disconnected items): removed the `Spacer()` between the "날짜" label and the `DatePicker`, so they sit adjacent as one visual group; `Spacer()` now sits between the date group and the budget-exclusion toggle, with a `Divider()` still separating them. Reads as two clear clusters: `[날짜 + date value]  ⋯spacer⋯  [divider][제외 토글]`.

Files touched:

- `WadeMoney/Screens/QuickAdd/QuickAddSheet.swift`
- `WadeMoney/Screens/QuickAdd/QuickAddViewModel.swift`
- `WadeMoneyTests/QuickAddViewModelTests.swift` (added `expenseRequiresMemo`; updated 3 existing tests to set `vm.memo` before asserting `canSave`)
- `WadeMoneyUITests/CoreFlowUITests.swift` (added a memo-entry step to `testQuickAddExpenseFlowUpdatesHistory` since save now requires memo)
- `docs/superpowers/specs/2026-07-01-wademoney-design-system.md` (§5.6: removed stepChips bullet, documented category-chip scroll-peek and the memo-required validity rule; §5.7: added a new cross-cutting principle — "핵심 CTA(예: 저장하기)는 스크롤 없이 최초 뷰포트 안에 보여야 한다")

Verification performed:

- Unit tests: 142/142 passed (`xcodebuild test -scheme WadeMoney`) on iPhone 17e simulator, up from 141 (one new memo-required test).
- E2E: both `CoreFlowUITests` (`testQuickAddExpenseFlowUpdatesHistory`, `testTabNavigationAndSettings`) passed.
- Visual verification via temporary XCUITest screenshot captures (added, screenshotted, then fully reverted each time — `git diff` on `CoreFlowUITests.swift` confirmed clean before each commit) at each iteration: save button visible without scrolling, 5th category chip visibly cut off at trailing edge, save button disabled until memo entered, "제외" toggle label renders without overflow even with the Korean-locale `DatePicker` compact string, and the final date-row grouping change.
- Committed as `6fedc7b` on `main` and pushed to `origin/main`. `docs/design/app-design-specification-analysis/` changes were deliberately left unstaged (user's own external design-tool artifacts, not app code) — same convention both agents have followed all along.

Known limitations / follow-up:

- None new. The pre-existing `SentenceHighlighter.swift` `Text + Text` deprecation warning is still outstanding (see AI Report section above).

## 2026-07-07 Codex Brainstorm: App Update Prompt + Feedback Mail

User request:

- Add WadeNote-style app update notification when the App Store has a newer version.
- Add a Settings entry for sending app improvement feedback by email.
- Use Superpowers brainstorming before implementation.

Context checked:

- Current WadeMoney `RootView` owns `SplashScreen` and `RootTabView`, making it the right integration point for update prompts after splash completion.
- Current `SettingsScreen` already has list-card rows and app version text, making it the right location for a quiet feedback mail row.
- WadeNote has existing reference implementations:
  - `AppVersion`
  - `UpdateChecker`
  - `UpdateAvailablePopup`
  - `BugReportDraft`
  - `MailComposeView`
- Lazyweb mobile settings feedback references supported adding feedback as a simple Settings support/help row, not as a prominent CTA.

User decisions:

- Proceed with option A: WadeNote-style implementation adapted to WadeMoney.
- Feedback recipient should use the recommended WadeNote address: `hgkim215@gmail.com`.
- Update prompt should be gentle, not forced.
- Prompt should appear after the splash screen, not during it.

Design spec written and committed:

- Commit: `abc5e8a docs(spec): design update prompt and feedback mail`
- Spec: `docs/superpowers/specs/2026-07-07-app-update-feedback-design.md`

Spec summary:

- Add pure `AppVersion` comparison.
- Add async `UpdateChecker` using iTunes Lookup with `bundleId` and `country=kr`, gated to once per 24 hours via `UserDefaults`.
- Add `UpdateAvailablePopup` with WadeMoney styling and `업데이트` / `나중에` actions.
- Integrate update checking in `RootView` after splash ends and on foreground return.
- Add `FeedbackMailDraft` and `MailComposeView`.
- Add Settings row `앱 개선 의견 보내기` under a quiet `도움말` section.
- If Mail is unavailable, copy `hgkim215@gmail.com` and show `메일 앱이 없어 주소를 복사했어요`.

Verification performed this turn:

- Design-only change; no app code changed.
- `rg` placeholder scan on the spec: passed.
- `git diff --check -- docs/superpowers/specs/2026-07-07-app-update-feedback-design.md`: passed.
- Spec committed successfully.

Known limitations / follow-up:

- Implementation has not started yet. Per Superpowers brainstorming, next step after user review is invoking `superpowers:writing-plans`.
- CodeGraph remains unavailable in this repo: `CodeGraph not initialized in /Users/mac/Documents/Projects/WadeMoney`.
- Original working tree still contains pre-existing uncommitted `docs/design/app-design-specification-analysis` changes and pre-existing handoff edits from Claude; do not treat those as part of this Codex spec commit.

## 2026-07-07 Codex Plan: App Update Prompt + Feedback Mail

User approval:

- User reviewed the design spec and replied `승인`.
- Per Superpowers brainstorming, Codex transitioned to `superpowers:writing-plans`.

What changed:

- Added implementation plan for the approved update prompt + feedback mail work.
- The plan decomposes the work into:
  - `AppVersion` pure version comparison.
  - `UpdateChecker` iTunes Lookup + 24-hour gate.
  - `UpdateAvailablePopup` + `RootView` integration after splash.
  - `FeedbackMailDraft`, `MailComposeView`, reusable `WadeToast`, and Settings feedback row.
  - Final verification and handoff update.

Files touched:

- `docs/superpowers/plans/2026-07-07-app-update-feedback.md`
- `docs/superpowers/plans/2026-07-02-codex-ui-ux-handoff.md`

Commits:

- `a7af482 docs(plan): app update prompt and feedback mail`

Verification performed this turn:

- Plan placeholder scan: passed. Only intended checkbox syntax and code examples were matched by the broad scan.
- `git diff --check -- docs/superpowers/plans/2026-07-07-app-update-feedback.md`: passed.
- No app code changed in this turn.

Known limitations / follow-up:

- Implementation has not started yet.
- Next required skill depends on user choice:
  - Recommended: `superpowers:subagent-driven-development`.
  - Alternative: `superpowers:executing-plans`.
- Original working tree still contains pre-existing uncommitted `docs/design/app-design-specification-analysis` changes and pre-existing handoff edits; continue avoiding unrelated staging.

## 2026-07-07 Codex Implementation: App Update Prompt + Feedback Mail

User context:

- User approved option A and then selected `Subagent-Driven`.
- The spawned subagent/worktree did not produce usable changes and status/close attempts stalled, so Codex switched to inline implementation in an isolated worktree and then cherry-picked the verified commits back to original `main`.

What changed:

- Added pure app-version comparison via `AppVersion`.
- Added `UpdateChecker` using iTunes Lookup (`bundleId`, `country=kr`) with a 24-hour `UserDefaults` gate, malformed JSON handling, invalid App Store URL rejection, and version comparison.
- Added `UpdateAvailablePopup`, styled with WadeMoney tokens, and wired it from `RootView` after splash completion and on app foreground return.
- Added Settings feedback mail flow:
  - `FeedbackMailDraft` with recipient `hgkim215@gmail.com`, subject `[WadeMoney] 앱 개선 의견`, and app/device/iOS context in the body.
  - `MailComposeView` wrapper around `MFMailComposeViewController`.
  - New Settings `도움말` section row: `앱 개선 의견 보내기`.
  - If Mail is unavailable, copy `hgkim215@gmail.com` to clipboard and show `메일 앱이 없어 주소를 복사했어요`.
- Extracted reusable `WadeToast` and reused it for the existing stats-tab unavailable toast and the new Settings fallback toast.
- `.gitignore` already includes `.worktrees/` from commit `09f9dc4`, because local Superpowers worktrees are operational artifacts.

Files touched:

- `.gitignore`
- `WadeMoney/RootView.swift`
- `WadeMoney/DesignSystem/WadeToast.swift`
- `WadeMoney/Screens/RootTabView.swift`
- `WadeMoney/Screens/Settings/SettingsScreen.swift`
- `WadeMoney/Screens/Settings/MailComposeView.swift`
- `WadeMoney/Support/FeedbackMailDraft.swift`
- `WadeMoney/Update/AppVersion.swift`
- `WadeMoney/Update/UpdateAvailablePopup.swift`
- `WadeMoney/Update/UpdateChecker.swift`
- `WadeMoneyTests/AppVersionTests.swift`
- `WadeMoneyTests/FeedbackMailDraftTests.swift`
- `WadeMoneyTests/UpdateCheckerTests.swift`
- `docs/superpowers/plans/2026-07-02-codex-ui-ux-handoff.md`

Commits on `main`:

- `09f9dc4 chore: ignore local worktrees`
- `9b0b1a0 feat(update): add app version comparison`
- `5ffb189 feat(update): add App Store lookup checker`
- `293ba72 feat(update): show App Store update prompt`
- `d0f932c feat(settings): add feedback mail action`

Verification performed:

- TDD red/green:
  - `AppVersionTests` initially failed with `Cannot find 'AppVersion' in scope`, then passed after implementation.
  - `UpdateCheckerTests` initially failed with `Cannot find 'UpdateChecker'` / `Cannot find 'UpdateInfo'`, then passed after implementation.
  - `FeedbackMailDraftTests` initially failed with `Cannot find 'FeedbackMailDraft' in scope`, then passed after implementation.
- Isolated worktree verification before cherry-pick:
  - `swift test --package-path WadeMoneyCore`: passed, 37 tests.
  - `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`: passed, 156 tests.
  - `xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`: passed.
  - `git diff --check`: passed.
- Original `main` verification after cherry-pick:
  - `xcodegen generate`: succeeded.
  - `swift test --package-path WadeMoneyCore`: passed, 37 tests.
  - `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`: passed, 156 tests.
  - `xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`: passed.
  - `git diff --check`: passed.

Known limitations / follow-up:

- The update prompt can only fully appear in production when App Store Lookup returns a version newer than the installed `CFBundleShortVersionString`; this was covered by unit tests rather than a live App Store visual trigger.
- Mail compose presentation depends on a configured Mail account on device. Simulator/no-Mail fallback is implemented by clipboard copy + toast; the draft body generation is unit-tested.
- UI was compile/test verified on the smallest available simulator target (`iPhone 17e`), but no manual screenshot pass was done in this turn.
- Original working tree still has pre-existing uncommitted `docs/design/app-design-specification-analysis/` changes and pre-existing handoff-file edits. Do not stage them accidentally.

## 2026-07-07 Codex Implementation: DEBUG Update Prompt Preview

User request:

- Add a Settings button in debug mode so the app update alert can be force-checked/previewed without waiting for a real App Store newer version response.

What changed:

- Added `DebugUpdatePrompt`, compiled only under `#if DEBUG`.
- Added a DEBUG-only Settings row in `도움말`: `업데이트 알림 미리보기`.
- Tapping the row posts an internal notification and makes `RootView` present the existing `UpdateAvailablePopup` immediately.
- The preview uses visible fake version `999.0` and an App Store WadeMoney search URL so developers can also tap through the existing update action without requiring a real App Store listing ID.
- Release builds were verified separately so the debug-only symbols do not leak into the production path.

Files touched:

- `WadeMoney/Update/DebugUpdatePrompt.swift`
- `WadeMoney/RootView.swift`
- `WadeMoney/Screens/Settings/SettingsScreen.swift`
- `WadeMoneyTests/DebugUpdatePromptTests.swift`
- `docs/superpowers/plans/2026-07-02-codex-ui-ux-handoff.md`

Commit on `main`:

- `4b5edca feat(debug): add update prompt preview action`

Verification performed:

- TDD red/green:
  - `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/DebugUpdatePromptTests` initially failed with `Cannot find 'DebugUpdatePrompt' in scope`.
  - Same focused test passed after implementation, 1 test.
- `xcodegen generate`: succeeded.
- `swift test --package-path WadeMoneyCore`: passed, 37 tests.
- `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`: passed, 157 tests.
- `xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`: passed.
- `xcodebuild build -scheme WadeMoney -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17e'`: passed.
- `git diff --check`: passed.

Known limitations / follow-up:

- This is a debug preview path only; the production update check is still driven by `UpdateChecker` and the App Store Lookup response.
- Superseded by the next bugfix section: the preview App Store URL no longer uses search and now points to the confirmed WadeMoney app detail URL.
- No manual simulator screenshot pass was done; verification was build/test focused.
- The handoff file and `docs/design/app-design-specification-analysis/` still contain pre-existing uncommitted changes from prior work; avoid staging unrelated docs/design files accidentally.

## 2026-07-07 Codex Bugfix: App Store Update Button URL

User request:

- The debug app update button showed the update popup, but tapping the update action failed with `LSApplicationWorkspaceErrorDomain Code=115` for `https://apps.apple.com/kr/search?term=WadeMoney`.

Root cause:

- The debug preview used an App Store search URL, which is not a stable app-detail destination for `openURL`.
- A temporary native-link helper converted detail URLs into `itms-apps://itunes.apple.com/app/id...`, but that scheme fails on Simulator because the App Store app is not available there.

What changed:

- Added `AppStoreLink.detailURL(...)` to build and validate only HTTPS `apps.apple.com` app-detail URLs that contain a numeric `/id...` path component.
- Updated the DEBUG update preview to use WadeMoney's actual App Store app ID `6786733784` and detail URL:
  `https://apps.apple.com/kr/app/wademoney-%EA%B0%84%EB%8B%A8-%EC%8B%AC%ED%94%8C-%EA%B0%80%EA%B3%84%EB%B6%80/id6786733784?uo=4`
- Updated `UpdateChecker` to reject App Store URLs without an app ID, so search URLs cannot reach the popup action path.
- Kept HTTPS detail URLs as the stored `UpdateInfo.storeURL`; on Simulator they open in Safari, and on real devices Apple can hand them off to the App Store app.

Files touched:

- `WadeMoney/Update/AppStoreLink.swift`
- `WadeMoney/Update/DebugUpdatePrompt.swift`
- `WadeMoney/Update/UpdateChecker.swift`
- `WadeMoneyTests/DebugUpdatePromptTests.swift`
- `WadeMoneyTests/UpdateCheckerTests.swift`
- `docs/superpowers/plans/2026-07-02-codex-ui-ux-handoff.md`

Verification performed:

- TDD red/green:
  - Before implementation, focused tests failed because the preview/checker returned `itms-apps://itunes.apple.com/app/id...` instead of the expected HTTPS App Store detail URL.
  - After implementation, `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/DebugUpdatePromptTests -only-testing:WadeMoneyTests/UpdateCheckerTests` passed, 7 tests.
- URL behavior:
  - `xcrun simctl openurl booted 'itms-apps://itunes.apple.com/app/id6786733784'` failed with `LSApplicationWorkspaceErrorDomain Code=115`.
  - `xcrun simctl openurl booted 'https://apps.apple.com/kr/app/wademoney-%EA%B0%84%EB%8B%A8-%EC%8B%AC%ED%94%8C-%EA%B0%80%EA%B3%84%EB%B6%80/id6786733784?uo=4'` succeeded.
- Full verification:
  - `swift test --package-path WadeMoneyCore`: passed, 37 tests.
  - `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`: passed, 158 tests.
  - `xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`: passed.
  - `xcodebuild build -scheme WadeMoney -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17e'`: passed.
  - `git diff --check`: passed.

Known limitations / follow-up:

- Real-device App Store handoff still needs a final manual tap check on a device with App Store available, but the URL is now the actual WadeMoney app detail URL instead of search.
- The handoff file and `docs/design/app-design-specification-analysis/` still contain pre-existing uncommitted changes from prior work; avoid staging unrelated docs/design files accidentally.

## 2026-07-07 Claude Implementation: Dashboard Trend Tap-to-Inspect + Category Detail Screens

User request:

- Dashboard's "지출 추세" (spending trend) card truncated the current period's total amount (e.g. "1,393,2…") because it was squeezed above a narrow per-bar column.
- User also wanted tapping "카테고리 비중" (category breakdown) to drill into more detail per category.
- Ran full Superpowers flow: brainstorming → writing-plans → subagent-driven-development (6 tasks, one implementer + one reviewer per task, then a final whole-branch review on `opus`).

Design decisions from brainstorming (user picked via `AskUserQuestion`, not defaults):

- Trend card: tapping any bar shows *that* bar's period+amount in a header (not just the current one); defaults to the current period when nothing is tapped.
- Category detail is two screens, not one: tapping the whole "카테고리 비중" card (donut+legend, not a specific legend row) opens a full ranked list of every category (no "기타" bucketing, unlike the dashboard donut which caps at 6+other); tapping a row in that list opens a single-category summary (total + percent) + transaction list, scoped to whatever period/offset the dashboard was showing at tap time (no in-screen period picker in either new screen).

What changed:

- `TrendCard` (`WadeMoney/Screens/Dashboard/DashboardComponents.swift`): removed the per-bar amount label (the truncation source); added a static, pure `TrendCard.selectedBar(in:id:)` helper and local `@State selectedID`; header now shows the selected bar's label+amount; tapping a bar highlights it and updates the header; `.onChange(of: bars)` resets selection back to the current period when the dashboard's period/kind changes.
- `DashboardViewModel.DashboardDisplay` gained a `period: Period` field (the same `Period` instance already resolved for the dashboard, not recomputed) so the new screens can reuse the exact period without redoing month-start-day logic.
- New `CategoryDetailViewModel` + `CategoryDetailScreen`: summary card (total + percent of period spend) + "최근 거래" transaction list for one category, bespoke (does not reuse/extend `HistoryViewModel`).
- New `CategoryBreakdownViewModel` + `CategoryBreakdownScreen`: full category ranking for the period via `Aggregator.totalsByCategory` directly (not `Donut.slices`, so no 6-item cap/bucketing); each row pushes into `CategoryDetailScreen`.
- `DashboardScreen`: wrapped `DonutCard` in a `Button` (guarded on non-empty donut data) that captures `d.period`/`d.periodLabel` at tap time and pushes `CategoryBreakdownScreen` via a second `.navigationDestination(isPresented:)`, following the existing `AIReportScreen` push pattern exactly (own `@Environment(\.dismiss)`, custom `backRow`, `.navigationBarBackButtonHidden(true)` on both new screens).

Real bug found and fixed during Task 6 verification (not in the original plan text): wrapping `DonutCard` in a `Button` made SwiftUI auto-compose its accessibility label from all child `Text` views (title + legend, including category names like "식비" when expense data exists). This collided with the pre-existing `CoreFlowUITests.testQuickAddExpenseFlowUpdatesHistory`'s `button(containing: "식비", in: app)` helper, which started grabbing the now-hidden (behind a sheet) donut button instead of the intended category chip. Fixed with a fixed `.accessibilityLabel("카테고리 비중")` on the button. The final whole-branch reviewer confirmed this is a minimal, well-targeted fix for a regression this same commit introduced, not scope creep — noting the trade-off that VoiceOver now announces only the fixed label instead of the composed total+legend (acceptable, logged as non-blocking).

Files touched:

- `WadeMoney/Screens/Dashboard/DashboardComponents.swift` (`TrendCard`)
- `WadeMoney/Screens/Dashboard/DashboardViewModel.swift` (`period` field)
- `WadeMoney/Screens/Dashboard/DashboardScreen.swift` (donut tap wiring)
- `WadeMoney/Screens/Dashboard/CategoryDetailViewModel.swift` (new)
- `WadeMoney/Screens/Dashboard/CategoryDetailScreen.swift` (new)
- `WadeMoney/Screens/Dashboard/CategoryBreakdownViewModel.swift` (new)
- `WadeMoney/Screens/Dashboard/CategoryBreakdownScreen.swift` (new)
- `WadeMoneyTests/TrendCardSelectionTests.swift` (new), `WadeMoneyTests/DashboardViewModelTests.swift`, `WadeMoneyTests/CategoryDetailViewModelTests.swift` (new), `WadeMoneyTests/CategoryBreakdownViewModelTests.swift` (new)
- `docs/superpowers/specs/2026-07-07-dashboard-trend-and-category-detail-design.md`, `docs/superpowers/plans/2026-07-07-dashboard-trend-and-category-detail.md`

Commits on `main` (6 task commits, all reviewed individually then as a whole branch):

- `e5ab9cf feat(dashboard): make trend card amount tap-to-inspect, fix truncation`
- `4e93a5d feat(dashboard): expose the resolved period on DashboardDisplay`
- `1f6be6d feat(dashboard): add category detail view model`
- `3f6f76a feat(dashboard): add category detail screen`
- `4475525 feat(dashboard): add category breakdown view model`
- `66f2b4d feat(dashboard): add category breakdown screen, wire up donut card tap`

Verification performed:

- Every task had its own implementer (TDD red/green where the task had pure logic) + independent task-reviewer subagent; all 6 Approved with 0 Critical/Important findings.
- New Swift files were added to the Xcode project via `xcodegen generate` (not hand-edited `project.pbxproj`, which stays gitignored) — confirmed safe since `project.yml`'s `WadeMoney` target source glob covers the whole `WadeMoney/` directory recursively.
- Manual screenshot verification (temporary XCUITest methods, added/run/exported via `xcresulttool`/reverted each time, confirmed via `git diff` empty before each commit) for: the trend card's no-truncation header + tap-to-highlight; the full breakdown-list → detail-screen tap flow with a real transaction.
- Final whole-branch review (opus) re-ran the full suite (green), traced cross-task interfaces by hand, and specifically checked that `CategoryBreakdownViewModel` and `CategoryDetailViewModel` compute "percent of period total" identically (same repository query, same `Aggregator.totalsByCategory`, same formula) so a category's percent never differs between the two screens. Verdict: **Ready to merge: Yes**, 0 Critical/Important, 4 non-blocking Minor notes (a provably-safe force-unwrap inherited from the plan's own code; the VoiceOver trade-off above; uncategorized-expense edge case shared with the pre-existing donut — unreachable since expense entry requires a category; one harmless redundant date-range filter).
- Full test suite at the end: 169 tests, 0 failures.

Known limitations / follow-up:

- None new. Pre-existing `SentenceHighlighter.swift` `Text + Text` deprecation warning still outstanding (see the AI Report section above).
