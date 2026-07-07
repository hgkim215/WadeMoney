# Special Expense Budget Exclusion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an expense-only `예산에서 제외` option that keeps special expenses in total spending and history while excluding them from budget consumed/remaining math.

**Architecture:** Store an `isExcludedFromBudget` flag on transactions and carry it through the core `TransactionRecord`. Keep existing real-spending aggregations intact, then introduce budget-aware aggregate values only where the budget card needs them. QuickAdd owns entry/edit state; History displays a fixed-height inline label without adding filters.

**Tech Stack:** SwiftData, Swift Testing, WadeMoneyCore, SwiftUI Observation, existing WadeMoney design tokens.

---

### Task 1: Core Domain And Aggregation

**Files:**
- Modify: `WadeMoneyCore/Sources/WadeMoneyCore/Domain.swift`
- Modify: `WadeMoneyCore/Sources/WadeMoneyCore/Aggregator.swift`
- Test: `WadeMoneyCore/Tests/WadeMoneyCoreTests/AggregatorTests.swift`

- [x] **Step 1: Write failing tests**
  - Add a transaction with `isExcludedFromBudget: true`.
  - Assert `Aggregator.totalExpense` still includes it.
  - Assert new `Aggregator.budgetedExpense` excludes it.

- [x] **Step 2: Run core test and confirm RED**
  - Run: `swift test --package-path WadeMoneyCore --filter AggregatorTests`
  - Expected: compile/test failure because `isExcludedFromBudget` and `budgetedExpense` do not exist.

- [x] **Step 3: Implement minimal domain/core aggregate**
  - Add `isExcludedFromBudget: Bool = false` to `TransactionRecord`.
  - Add `Aggregator.budgetedExpense`.

- [x] **Step 4: Run core tests and confirm GREEN**
  - Run: `swift test --package-path WadeMoneyCore --filter AggregatorTests`
  - Expected: pass.

### Task 2: Persistence And Dashboard Summary

**Files:**
- Modify: `WadeMoney/Models/TransactionModel.swift`
- Modify: `WadeMoney/Mapping/ModelMapping.swift`
- Modify: `WadeMoney/Stores/LedgerRepository.swift`
- Test: `WadeMoneyTests/LedgerRepositoryTests.swift`
- Test: `WadeMoneyTests/ModelMappingTests.swift`

- [x] **Step 1: Write failing repository tests**
  - Add an excluded expense via `addTransaction`.
  - Assert it round-trips through `allTransactions`.
  - Assert dashboard `totalExpense` includes it, while `budgetedExpense`, `remaining`, and `consumedFraction` exclude it.

- [x] **Step 2: Run app tests and confirm RED**
  - Run the targeted app tests with XcodeBuildMCP or `xcodebuild test` if MCP is unavailable.
  - Expected: compile failure because persistence flag and repository signatures do not exist.

- [x] **Step 3: Implement persistence and summary**
  - Add `isExcludedFromBudget` to `TransactionModel`.
  - Thread it through mapping, create, and update.
  - Add `budgetedExpense` and `excludedExpense` to `DashboardSummary`.
  - Use `budgetedExpense` for remaining, consumed, and projected budget math while keeping `totalExpense` real.

- [x] **Step 4: Run targeted app tests and confirm GREEN**
  - Expected: pass.

### Task 3: QuickAdd Entry And Edit State

**Files:**
- Modify: `WadeMoney/Screens/QuickAdd/QuickAddViewModel.swift`
- Modify: `WadeMoney/Screens/QuickAdd/QuickAddSheet.swift`
- Test: `WadeMoneyTests/QuickAddViewModelTests.swift`
- Test: `WadeMoneyTests/QuickAddEditTests.swift`

- [x] **Step 1: Write failing QuickAdd tests**
  - New expense can save with `isExcludedFromBudget = true`.
  - Editing an excluded transaction loads the toggle as true.
  - Switching to income clears the flag.

- [x] **Step 2: Run targeted QuickAdd tests and confirm RED**
  - Expected: compile/test failure because the view model flag does not exist.

- [x] **Step 3: Implement QuickAdd state and UI**
  - Add `isExcludedFromBudget` to the view model.
  - Include it in save/update calls.
  - Add a secondary toggle-style row in the sheet, visible only for expenses.

- [x] **Step 4: Run targeted QuickAdd tests and confirm GREEN**
  - Expected: pass.

### Task 4: History Label And Fixed Row Height

**Files:**
- Modify: `WadeMoney/Screens/History/HistoryViewModel.swift`
- Modify: `WadeMoney/Screens/History/HistoryScreen.swift`
- Test: `WadeMoneyTests/HistoryViewModelTests.swift`

- [x] **Step 1: Write failing History test**
  - Excluded transactions expose `showsBudgetExcludedLabel == true`.
  - Normal transactions and income rows expose `false`.

- [x] **Step 2: Run targeted History test and confirm RED**
  - Expected: compile/test failure because the row flag does not exist.

- [x] **Step 3: Implement row flag and inline label**
  - Add row flag to `HistoryViewModel.Row`.
  - Render `예산 제외` inline in the title row without adding a third line.
  - Keep row padding/min-height stable so labelled and normal cards remain equal height.

- [x] **Step 4: Run targeted History tests and confirm GREEN**
  - Expected: pass.

### Task 5: Dashboard Display Copy

**Files:**
- Modify: `WadeMoney/Screens/Dashboard/DashboardViewModel.swift`
- Modify: `WadeMoney/Screens/Dashboard/DashboardComponents.swift`
- Test: `WadeMoneyTests/DashboardViewModelTests.swift`

- [x] **Step 1: Write failing Dashboard view-model test**
  - Display total text includes excluded expense.
  - Remaining budget excludes it.
  - Secondary budget note shows budget-reflected and excluded values when excluded spending exists.

- [x] **Step 2: Run targeted Dashboard tests and confirm RED**
  - Expected: compile/test failure because display note fields do not exist.

- [x] **Step 3: Implement display note and UI**
  - Add optional `budgetBasisText` / equivalent to display.
  - Show the secondary line in the budget block only when useful.

- [x] **Step 4: Run targeted Dashboard tests and confirm GREEN**
  - Expected: pass.

### Task 6: Full Verification And Handoff

**Files:**
- Modify: `docs/superpowers/plans/2026-07-02-codex-ui-ux-handoff.md`

- [x] **Step 1: Run full test suite**
  - Prefer XcodeBuildMCP `test_sim`.
  - Also run `swift test --package-path WadeMoneyCore` if the package tests are not covered.

- [x] **Step 2: Build/run simulator**
  - Prefer XcodeBuildMCP `build_run_sim`.
  - Check QuickAdd, Dashboard, and History manually on the smallest available simulator.

- [x] **Step 3: Update handoff**
  - Document files changed, verification results, and any known visual follow-up.
