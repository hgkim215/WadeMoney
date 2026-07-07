# Special Expense Budget Exclusion Design

Date: 2026-07-03

## Decision

Add a lightweight `예산에서 제외` option for unusual one-off expenses.

The selected UX is:

- Quick Add sheet: add a secondary toggle for expense records only.
- History list/detail: show an `예산 제외` label on excluded records.
- Do not add History filters for this feature.

## Product Rationale

Some expenses are real and should remain in the user's record, but should not distort the monthly budget. Example: a large first-paycheck gift to parents.

The feature should make the budget feel fair without turning the app into accounting software.

## Behavior

An excluded expense:

- Is still saved as an expense.
- Appears in History.
- Keeps its category and memo.
- Shows an `예산 제외` label in transaction rows and edit views.
- Is excluded from budget consumed percentage and remaining budget.
- Still counts in Dashboard main total spending.

Recommended implementation semantics:

- Dashboard main block should continue to show real `totalExpense`, including excluded expenses.
- Dashboard budget progress, consumed percentage, and remaining budget should use `budgetedExpense`, excluding flagged expenses.
- History should show the actual expense amount with the label.
- Keep `totalExpense` available as real spending, but introduce a separate aggregate for budget math so wording stays honest.
- If the dashboard has enough room, show a small secondary budget line such as `예산 반영 ₩680,000 · 제외 ₩500,000`.
- Category ratio, trend, widgets, and AI report should keep using real spending unless a specific budget-focused component is being rendered.

## UX Details

Quick Add sheet:

- Place the toggle below memo and above keypad/save area, or below category if memo remains compact.
- Copy:
  - Title: `예산에서 제외`
  - Helper: `총 내역에는 남고, 이번 달 예산 계산에는 빠져요`
- The control should be visually secondary, not a third transaction type.
- It should only appear for `지출`; switching to `수입` disables/clears the flag.

History:

- Add a small warm/gold label: `예산 제외`.
- All transaction rows/cards must keep the same height whether the label exists or not.
- The label should sit inline with the title or in an otherwise reserved area; it must not add a third line or expand the row.
- No new filter chips.
- Editing an excluded transaction should preserve the flag and allow toggling it off.

## Data And Engineering Notes

Likely model changes:

- Add a Boolean flag to `TransactionModel`, e.g. `isExcludedFromBudget`.
- Add the same field to `TransactionRecord`.
- Update `TransactionModel.toRecord()`.
- Update `LedgerRepository.addTransaction` and `updateTransaction`.

Likely aggregation changes:

- Add a budget-aware expense aggregate, e.g. `Aggregator.budgetedExpense`.
- Add category totals variant if category ratio should exclude special expenses.
- Update dashboard summary to expose both real total and budgeted total if needed.
- Update widgets and AI report based on the final product decision above.

Tests to add:

- Aggregator excludes flagged expenses from budget math.
- Repository create/edit preserves exclusion flag.
- QuickAdd editing round-trips the toggle.
- Dashboard main total includes excluded expenses.
- Dashboard budget remaining/consumed uses budgeted expense.
- History row shows `예산 제외` label.

## Mockup

Local mockup:

- `docs/superpowers/mockups/special-expense-flow.html`

When the local server is running:

- `http://127.0.0.1:8765/docs/superpowers/mockups/special-expense-flow.html`
