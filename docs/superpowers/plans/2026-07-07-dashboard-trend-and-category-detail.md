# Dashboard Trend Tap-to-Inspect + Category Detail Screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the truncated total-spend label on the Dashboard's "지출 추세" trend card by moving it to a tappable header, and let users tap any bar to inspect that period's amount; add two new screens reached by tapping "카테고리 비중" — a full category ranking list, and a per-category summary + transaction list.

**Architecture:** `TrendCard` gets a pure, testable `selectedBar(in:id:)` helper plus local `@State` selection and tap gestures — no view-model or data changes. `DashboardViewModel.DashboardDisplay` gains a `period: Period` field so the new screens can reuse the exact period the dashboard already resolved (no month-start-day recomputation). Two new self-contained screen+view-model pairs (`CategoryDetailScreen`/`CategoryDetailViewModel`, `CategoryBreakdownScreen`/`CategoryBreakdownViewModel`) follow the existing `AIReportScreen` pattern: pushed via `NavigationStack.navigationDestination(isPresented:)`, own `@Environment(\.dismiss)` + custom back row, construct their own view model in `.onAppear`. `CategoryDetailScreen` is built first (it's a leaf with no dependency on the other new screen); `CategoryBreakdownScreen` is built last since it references `CategoryDetailScreen` and is also the task that wires the dashboard entry point, so every task in this plan builds and is reviewable independently.

**Tech Stack:** SwiftUI, `@Observable` view models, Swift Testing (`import Testing`, `@Test`, `#expect`), XCTest for UI screenshot verification, WadeMoneyCore (`Period`, `Aggregator`, `CategoryRef`, `TransactionRecord`).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-07-dashboard-trend-and-category-detail-design.md`.
- Do not change the dashboard's actual selected period (`vm.offset`/`vm.kind`) from the trend card tap — the tap only changes what the trend card itself displays.
- Do not reuse or extend `HistoryViewModel` — the new detail list is a separate, simpler view model (no search/grouping needed).
- New screens must match the existing `AIReportScreen` navigation convention exactly: own `@Environment(\.dismiss)`, a `backRow` button (not the default nav bar back button), `.navigationBarBackButtonHidden(true)`.
- Use only existing design tokens (`WadeColors`, `WadeFont`, `WadeRadius`, `WadeSpacing`, `WadeShadow`, `Icon`) — no new tokens.
- `CategoryBreakdownScreen` lists **every** category with spending in the period (no "기타" bucketing) — this is intentionally different from the dashboard donut legend, which caps at 6 + other.
- Both new screens use the period the dashboard was showing at tap time — no in-screen period picker.
- Simulator verification target: `platform=iOS Simulator,name=iPhone 17e` (project convention).

---

### Task 1: Trend card tap-to-inspect

**Files:**
- Modify: `WadeMoney/Screens/Dashboard/DashboardComponents.swift` (the `TrendCard` struct, currently lines 351-392)
- Test: `WadeMoneyTests/TrendCardSelectionTests.swift` (create)

**Interfaces:**
- Produces: `TrendCard.selectedBar(in bars: [DashboardViewModel.TrendBar], id: Int?) -> DashboardViewModel.TrendBar?` — a static, pure function later tasks do not depend on, but is the core logic this task must prove correct.

- [ ] **Step 1: Write the failing tests**

Create `WadeMoneyTests/TrendCardSelectionTests.swift`:

```swift
import Testing
import WadeMoneyCore
@testable import WadeMoney

struct TrendCardSelectionTests {
    private func bar(_ id: Int, isCurrent: Bool) -> DashboardViewModel.TrendBar {
        DashboardViewModel.TrendBar(id: id, label: "\(id)월", valueText: "\(id * 1000)", heightFraction: 0.5, isCurrent: isCurrent)
    }

    @Test func nilSelectionPicksCurrentBar() {
        let bars = [bar(0, isCurrent: false), bar(1, isCurrent: true)]
        let result = TrendCard.selectedBar(in: bars, id: nil)
        #expect(result?.id == 1)
    }

    @Test func explicitSelectionPicksThatBar() {
        let bars = [bar(0, isCurrent: false), bar(1, isCurrent: true)]
        let result = TrendCard.selectedBar(in: bars, id: 0)
        #expect(result?.id == 0)
    }

    @Test func unknownSelectionFallsBackToCurrentBar() {
        let bars = [bar(0, isCurrent: false), bar(1, isCurrent: true)]
        let result = TrendCard.selectedBar(in: bars, id: 99)
        #expect(result?.id == 1)
    }

    @Test func emptyBarsReturnsNil() {
        let result = TrendCard.selectedBar(in: [], id: nil)
        #expect(result == nil)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/TrendCardSelectionTests`
Expected: FAIL to build — `type 'TrendCard' has no member 'selectedBar'`.

- [ ] **Step 3: Replace `TrendCard` with the tap-to-inspect version**

In `WadeMoney/Screens/Dashboard/DashboardComponents.swift`, replace the entire existing `TrendCard` struct (currently the last struct in the file, starting `struct TrendCard: View {`) with:

```swift
struct TrendCard: View {
    @Environment(\.colorScheme) private var scheme
    let bars: [DashboardViewModel.TrendBar]
    @State private var selectedID: Int?

    private var selectedBar: DashboardViewModel.TrendBar? {
        TrendCard.selectedBar(in: bars, id: selectedID)
    }

    var body: some View {
        card(scheme, minHeight: WadeSpacing.dashboardBlockHeight) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("지출 추세").font(WadeFont.pretendard(15, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                    Spacer()
                    if let selectedBar {
                        Text("\(selectedBar.label) · \(selectedBar.valueText)")
                            .font(WadeFont.pretendard(13, weight: .heavy))
                            .foregroundStyle(WadeColors.primary(scheme))
                    }
                }
                if bars.contains(where: { $0.heightFraction > 0 }) {
                    HStack(alignment: .bottom, spacing: 5) {
                        ForEach(bars) { bar in
                            let isSelected = bar.id == selectedBar?.id
                            VStack(spacing: 7) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(isSelected ? WadeColors.primary(scheme) : WadeColors.barmuted(scheme))
                                    .frame(maxWidth: 20)
                                    .frame(height: max(6, bar.heightFraction * 100))
                                Text(bar.label).font(WadeFont.pretendard(9.5, weight: isSelected ? .heavy : .semibold))
                                    .foregroundStyle(isSelected ? WadeColors.ink(scheme) : WadeColors.ink3(scheme))
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedID = bar.id }
                        }
                    }
                    .frame(height: 112, alignment: .bottom)
                } else {
                    VStack(spacing: 7) {
                        Icon("bar_chart", size: 28)
                            .foregroundStyle(WadeColors.primary(scheme))
                        Text("아직 추세가 없어요")
                            .font(WadeFont.pretendard(13, weight: .semibold))
                            .foregroundStyle(WadeColors.ink3(scheme))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 112)
                    .background(WadeColors.card2(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.smallTile, style: .continuous))
                }
            }
        }
        .onChange(of: bars) { selectedID = nil }
    }

    static func selectedBar(in bars: [DashboardViewModel.TrendBar], id: Int?) -> DashboardViewModel.TrendBar? {
        if let id, let match = bars.first(where: { $0.id == id }) { return match }
        return bars.first { $0.isCurrent }
    }
}
```

Note what changed from the original: the narrow per-bar `valueText` label above each bar is gone (that was the truncation source); the header row now shows the selected bar's label+amount; bar/label highlighting is driven by `isSelected` instead of `bar.isCurrent`; tapping a bar sets `selectedID`; changing `bars` (period/kind navigation) resets the selection back to the current period.

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/TrendCardSelectionTests`
Expected: PASS, 4 tests.

- [ ] **Step 5: Run the full unit test suite to check for regressions**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: PASS, 0 failures.

- [ ] **Step 6: Visually verify on simulator**

Add a temporary screenshot test to `WadeMoneyUITests/CoreFlowUITests.swift`, right after the `button(containing:in:)` helper method:

```swift
    func testTempTrendCardTapScreenshot() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["한눈에"].waitForExistence(timeout: 15))

        let attachment1 = XCTAttachment(screenshot: app.screenshot())
        attachment1.lifetime = .keepAlways
        attachment1.name = "trendCard_default"
        add(attachment1)

        // 지출 추세 카드 안의 임의 지점을 눌러본다 — 정확한 막대 프레임을 몰라도
        // 카드 제목 기준 상대 좌표로 탭하고, 헤더 텍스트가 바뀌는지로 판단한다.
        let trendTitle = app.staticTexts["지출 추세"]
        XCTAssertTrue(trendTitle.waitForExistence(timeout: 5))
        let cardFrame = trendTitle.frame
        let tapPoint = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: cardFrame.minX + 40, dy: cardFrame.maxY + 60))
        tapPoint.tap()

        let attachment2 = XCTAttachment(screenshot: app.screenshot())
        attachment2.lifetime = .keepAlways
        attachment2.name = "trendCard_afterTap"
        add(attachment2)
    }
```

Run it and export the screenshots:

```bash
rm -rf /tmp/wademoney-trend-test.xcresult
xcodebuild test -scheme WadeMoneyUITests -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:WadeMoneyUITests/CoreFlowUITests/testTempTrendCardTapScreenshot \
  -resultBundlePath /tmp/wademoney-trend-test.xcresult
mkdir -p /tmp/wademoney-trend-screens
xcrun xcresulttool export attachments --path /tmp/wademoney-trend-test.xcresult --output-path /tmp/wademoney-trend-screens
```

Read both exported PNGs (path printed by the export command) with the Read tool. Confirm:
- `trendCard_default`: the header shows the current period's label + amount with no truncation (no "…").
- `trendCard_afterTap`: a different bar is now highlighted and the header amount changed to match it (if the tap happened to land on the already-current bar, retry with a different `dx` offset before concluding the feature doesn't work).

Then remove the temporary test method from `WadeMoneyUITests/CoreFlowUITests.swift` and confirm `git diff -- WadeMoneyUITests/CoreFlowUITests.swift` is empty.

- [ ] **Step 7: Commit**

```bash
git add WadeMoney/Screens/Dashboard/DashboardComponents.swift WadeMoneyTests/TrendCardSelectionTests.swift
git commit -m "feat(dashboard): make trend card amount tap-to-inspect, fix truncation"
```

---

### Task 2: Expose the dashboard's resolved `Period`

**Files:**
- Modify: `WadeMoney/Screens/Dashboard/DashboardViewModel.swift`
- Modify: `WadeMoneyTests/DashboardViewModelTests.swift`

**Interfaces:**
- Produces: `DashboardViewModel.DashboardDisplay.period: Period`. Task 5 and Task 6 both construct their view models/screens with this value.

- [ ] **Step 1: Write the failing test**

In `WadeMoneyTests/DashboardViewModelTests.swift`, add one assertion to the existing `buildsMonthDisplayWithPaceAndDonut` test — insert it right after the `#expect(d.periodLabel == "2026년 7월")` line:

```swift
        #expect(d.period.kind == .month)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/DashboardViewModelTests/buildsMonthDisplayWithPaceAndDonut`
Expected: FAIL to build — `value of type 'DashboardViewModel.DashboardDisplay' has no member 'period'`.

- [ ] **Step 3: Add the `period` field**

In `WadeMoney/Screens/Dashboard/DashboardViewModel.swift`, in the `DashboardDisplay` struct, add the field after `trend`:

```swift
    struct DashboardDisplay: Equatable {
        let periodLabel: String
        let scopeText: String
        let totalText: String
        let hasExpense: Bool
        let budgetText: String?
        let budgetBasisText: String?
        let remainText: String?
        let consumedPercentText: String?
        let consumedFraction: Double?
        let pace: PaceBadge?
        let dayBudget: DayBudgetInfo?
        let donut: [DonutLegendItem]
        let trend: [TrendBar]
        let period: Period
    }
```

Then in `build(_:categories:)`, add `period: s.period` to the returned `DashboardDisplay` (insert right after the `periodLabel:` line):

```swift
        return DashboardDisplay(
            periodLabel: PeriodLabel.text(kind: kind, period: s.period, now: now, calendar: calendar),
            scopeText: scope,
            totalText: Won.string(s.totalExpense),
            hasExpense: s.totalExpense > 0,
            budgetText: s.budget.map { Won.string($0) },
            budgetBasisText: budgetBasisText,
            remainText: s.remaining.map { Won.string($0) },
            consumedPercentText: s.consumedFraction.map { "\(Int(($0 * 100).rounded()))%" },
            consumedFraction: s.consumedFraction,
            pace: pace,
            dayBudget: dayBudget,
            donut: legend,
            trend: buildTrend(currentPeriodStart: s.period.start),
            period: s.period
        )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/DashboardViewModelTests`
Expected: PASS, all 3 tests in this file.

- [ ] **Step 5: Run the full unit test suite to check for regressions**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: PASS, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add WadeMoney/Screens/Dashboard/DashboardViewModel.swift WadeMoneyTests/DashboardViewModelTests.swift
git commit -m "feat(dashboard): expose the resolved period on DashboardDisplay"
```

---

### Task 3: `CategoryDetailViewModel`

**Files:**
- Create: `WadeMoney/Screens/Dashboard/CategoryDetailViewModel.swift`
- Test: `WadeMoneyTests/CategoryDetailViewModelTests.swift` (create)

**Interfaces:**
- Consumes: `LedgerRepository.transactions(from:to:) throws -> [TransactionRecord]` (existing, `WadeMoney/Stores/LedgerRepository.swift:102`), `Aggregator.totalsByCategory(_:in:) -> [CategoryTotal]` (existing, `WadeMoneyCore/Sources/WadeMoneyCore/Aggregator.swift:44`), `Won.string(_:) -> String` (existing), `Decimal.doubleValue` (existing, `WadeMoneyCore/Sources/WadeMoneyCore/Decimal+Double.swift`).
- Produces: `CategoryDetailViewModel(repository:categoryID:categoryName:period:calendar:)`, `.load()`, `.totalText: String`, `.percentText: String`, `.rows: [CategoryDetailViewModel.Row]` where `Row` has `id: UUID`, `dateText: String`, `memo: String`, `amountText: String`, `showsBudgetExcludedLabel: Bool`. Task 4 constructs this and reads these properties.

- [ ] **Step 1: Write the failing tests**

Create `WadeMoneyTests/CategoryDetailViewModelTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct CategoryDetailViewModelTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }
    func makeRepo() throws -> (LedgerRepository, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        return (LedgerRepository(context: container.mainContext), container)
    }
    func catID(_ repo: LedgerRepository, _ name: String) throws -> UUID {
        try repo.allCategories(includeArchived: false).first { $0.name == name }!.id
    }

    @Test func summarizesTotalAndPercentForOneCategory() throws {
        let (repo, container) = try makeRepo()
        let food = try catID(repo, "식비"); let cafe = try catID(repo, "카페")
        try repo.addTransaction(amount: 300_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))
        try repo.addTransaction(amount: 100_000, type: .expense, categoryID: cafe, memo: nil, date: date(2026, 7, 6))

        let period = Period(kind: .month, start: date(2026, 7, 1), end: date(2026, 8, 1))
        let vm = CategoryDetailViewModel(repository: repo, categoryID: food, categoryName: "식비", period: period, calendar: utc)
        vm.load()

        #expect(vm.totalText == "300,000")
        #expect(vm.percentText == "75%")
        _ = container
    }

    @Test func listsOnlyThisCategorysTransactionsNewestFirst() throws {
        let (repo, container) = try makeRepo()
        let food = try catID(repo, "식비"); let cafe = try catID(repo, "카페")
        try repo.addTransaction(amount: 12_000, type: .expense, categoryID: food, memo: "점심 식사", date: date(2026, 7, 6))
        try repo.addTransaction(amount: 85_000, type: .expense, categoryID: food, memo: "장보기", date: date(2026, 7, 4))
        try repo.addTransaction(amount: 6_500, type: .expense, categoryID: cafe, memo: "카페", date: date(2026, 7, 1))

        let period = Period(kind: .month, start: date(2026, 7, 1), end: date(2026, 8, 1))
        let vm = CategoryDetailViewModel(repository: repo, categoryID: food, categoryName: "식비", period: period, calendar: utc)
        vm.load()

        #expect(vm.rows.count == 2)
        #expect(vm.rows[0].memo == "점심 식사")
        #expect(vm.rows[0].dateText == "7/6")
        #expect(vm.rows[0].amountText == "\u{2212}12,000")
        #expect(vm.rows[1].memo == "장보기")
        _ = container
    }

    @Test func fallsBackToCategoryNameWhenMemoIsEmpty() throws {
        let (repo, container) = try makeRepo()
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 12_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 6))

        let period = Period(kind: .month, start: date(2026, 7, 1), end: date(2026, 8, 1))
        let vm = CategoryDetailViewModel(repository: repo, categoryID: food, categoryName: "식비", period: period, calendar: utc)
        vm.load()

        #expect(vm.rows[0].memo == "식비")
        _ = container
    }

    @Test func flagsBudgetExcludedTransactions() throws {
        let (repo, container) = try makeRepo()
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 500_000, type: .expense, categoryID: food, memo: "용돈", date: date(2026, 7, 6), isExcludedFromBudget: true)

        let period = Period(kind: .month, start: date(2026, 7, 1), end: date(2026, 8, 1))
        let vm = CategoryDetailViewModel(repository: repo, categoryID: food, categoryName: "식비", period: period, calendar: utc)
        vm.load()

        #expect(vm.rows[0].showsBudgetExcludedLabel == true)
        _ = container
    }
}
```

(`\u{2212}` is the Unicode MINUS SIGN character the rest of the app uses for negative amounts — see `HistoryViewModel.row(_:byID:)`'s `let sign = isIncome ? "+" : "−"`.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/CategoryDetailViewModelTests`
Expected: FAIL to build — `cannot find 'CategoryDetailViewModel' in scope`.

- [ ] **Step 3: Create `CategoryDetailViewModel`**

Create `WadeMoney/Screens/Dashboard/CategoryDetailViewModel.swift`:

```swift
import Foundation
import Observation
import WadeMoneyCore

@MainActor
@Observable
final class CategoryDetailViewModel {
    struct Row: Identifiable {
        let id: UUID
        let dateText: String
        let memo: String
        let amountText: String
        let showsBudgetExcludedLabel: Bool
    }

    private let repository: LedgerRepository
    private let categoryID: UUID
    private let categoryName: String
    private let period: Period
    private let calendar: Calendar

    private(set) var totalText: String = "0"
    private(set) var percentText: String = "0%"
    private(set) var rows: [Row] = []

    init(
        repository: LedgerRepository,
        categoryID: UUID,
        categoryName: String,
        period: Period,
        calendar: Calendar
    ) {
        self.repository = repository
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.period = period
        self.calendar = calendar
    }

    func load() {
        let txns = (try? repository.transactions(from: period.start, to: period.end)) ?? []
        let totals = Aggregator.totalsByCategory(txns, in: period)
        let grandTotal = totals.reduce(Decimal(0)) { $0 + $1.total }
        let categoryTotal = totals.first { $0.categoryID == categoryID }?.total ?? 0

        totalText = Won.string(categoryTotal)
        percentText = grandTotal > 0
            ? "\(Int(((categoryTotal / grandTotal).doubleValue * 100).rounded()))%"
            : "0%"

        rows = txns
            .filter { $0.type == .expense && $0.categoryID == categoryID }
            .sorted { $0.date != $1.date ? $0.date > $1.date : $0.createdAt > $1.createdAt }
            .map { t in
                Row(
                    id: t.id,
                    dateText: dateLabel(t.date),
                    memo: t.memo?.isEmpty == false ? t.memo! : categoryName,
                    amountText: "\u{2212}\(Won.string(t.amount))",
                    showsBudgetExcludedLabel: t.isExcludedFromBudget
                )
            }
    }

    private func dateLabel(_ date: Date) -> String {
        let c = calendar.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 0)/\(c.day ?? 0)"
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/CategoryDetailViewModelTests`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add WadeMoney/Screens/Dashboard/CategoryDetailViewModel.swift WadeMoneyTests/CategoryDetailViewModelTests.swift
git commit -m "feat(dashboard): add category detail view model"
```

---

### Task 4: `CategoryDetailScreen`

**Files:**
- Create: `WadeMoney/Screens/Dashboard/CategoryDetailScreen.swift`

**Interfaces:**
- Consumes: `CategoryDetailViewModel(repository:categoryID:categoryName:period:calendar:)`, `.totalText`, `.percentText`, `.rows` (Task 3).
- Produces: `CategoryDetailScreen(categoryID: UUID, categoryName: String, categoryIconName: String, categoryColorHex: String, period: Period, periodLabel: String, repository: LedgerRepository)` — Task 6 constructs this as a `navigationDestination`.

This screen has no entry point yet (nothing pushes it), so it cannot be screenshotted in a live app flow this task — that happens in Task 6 once `CategoryBreakdownScreen` can push it. Verify this task with a successful build only.

- [ ] **Step 1: Create `CategoryDetailScreen`**

Create `WadeMoney/Screens/Dashboard/CategoryDetailScreen.swift`:

```swift
import SwiftUI
import WadeMoneyCore

struct CategoryDetailScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CategoryDetailViewModel?

    let categoryID: UUID
    let categoryName: String
    let categoryIconName: String
    let categoryColorHex: String
    let period: Period
    let periodLabel: String
    let repository: LedgerRepository

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WadeSpacing.cardGap) {
                backRow
                if let vm = viewModel {
                    summaryCard(vm)
                    Text("최근 거래")
                        .font(WadeFont.pretendard(15, weight: .heavy))
                        .foregroundStyle(WadeColors.ink(scheme))
                    if vm.rows.isEmpty {
                        emptyState
                    } else {
                        listCard(vm)
                    }
                }
            }
            .padding(.horizontal, WadeSpacing.screenH)
            .padding(.top, WadeSpacing.contentTop)
            .padding(.bottom, WadeSpacing.contentBottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WadeColors.bg(scheme))
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if viewModel == nil {
                let vm = CategoryDetailViewModel(
                    repository: repository,
                    categoryID: categoryID,
                    categoryName: categoryName,
                    period: period,
                    calendar: .current
                )
                vm.load()
                viewModel = vm
            }
        }
    }

    private var backRow: some View {
        Button { dismiss() } label: {
            HStack(spacing: 3) { Icon("chevron_left", size: 18); Text("카테고리별 지출").font(WadeFont.pretendard(14, weight: .semibold)) }
                .foregroundStyle(WadeColors.ink2(scheme))
        }.buttonStyle(.plain)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let sh = WadeShadow.card(scheme)
        return content()
            .padding(WadeSpacing.cardPadding)
            .background(WadeColors.card(scheme))
            .clipShape(RoundedRectangle(cornerRadius: WadeRadius.card, style: .continuous))
            .shadow(color: sh.color, radius: sh.radius, y: sh.y)
    }

    private func summaryCard(_ vm: CategoryDetailViewModel) -> some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Icon(categoryIconName, size: 22).foregroundStyle(Color(hex: categoryColorHex))
                        .frame(width: 42, height: 42)
                        .background(Color(hex: categoryColorHex).opacity(0.13), in: RoundedRectangle(cornerRadius: WadeRadius.iconTile))
                    Text(categoryName).font(WadeFont.pretendard(19, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(periodLabel).font(WadeFont.pretendard(12.5, weight: .semibold)).foregroundStyle(WadeColors.ink3(scheme))
                    Text("₩\(vm.totalText)").font(WadeFont.pretendard(22, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                    Text("· 지출 \(vm.percentText)").font(WadeFont.pretendard(13, weight: .bold)).foregroundStyle(WadeColors.ink2(scheme))
                }
            }
        }
    }

    private func listCard(_ vm: CategoryDetailViewModel) -> some View {
        VStack(spacing: 0) {
            ForEach(vm.rows) { row in
                rowView(row)
                if row.id != vm.rows.last?.id {
                    Divider().overlay(WadeColors.line(scheme)).padding(.leading, 16)
                }
            }
        }
        .background(WadeColors.card(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.listCard, style: .continuous))
        .shadow(color: WadeShadow.list(scheme).color, radius: WadeShadow.list(scheme).radius, y: WadeShadow.list(scheme).y)
    }

    private func rowView(_ row: CategoryDetailViewModel.Row) -> some View {
        HStack(spacing: 13) {
            Text(row.dateText)
                .font(WadeFont.pretendard(12, weight: .semibold))
                .foregroundStyle(WadeColors.ink3(scheme))
                .frame(width: 36, alignment: .leading)
            HStack(spacing: 6) {
                Text(row.memo).font(WadeFont.pretendard(14.5, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme)).lineLimit(1)
                if row.showsBudgetExcludedLabel {
                    Text("예산 제외")
                        .font(WadeFont.pretendard(10.5, weight: .heavy))
                        .foregroundStyle(Color(hex: "#B4811F"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#D3A850").opacity(scheme == .dark ? 0.18 : 0.16), in: Capsule())
                        .fixedSize()
                }
            }
            Spacer()
            Text(row.amountText).font(WadeFont.pretendard(15, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .frame(minHeight: 64)
    }

    private var emptyState: some View {
        VStack(spacing: 11) {
            Icon("receipt_long", size: 38, filled: false).foregroundStyle(WadeColors.ink3(scheme))
                .frame(width: 74, height: 74)
                .background(WadeColors.card2(scheme), in: Circle())
            Text("거래 내역이 없어요")
                .font(WadeFont.pretendard(16, weight: .heavy))
                .foregroundStyle(WadeColors.ink2(scheme))
        }
        .frame(maxWidth: .infinity).padding(.top, 64)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Run the full unit test suite to check for regressions**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: PASS, 0 failures.

- [ ] **Step 4: Commit**

```bash
git add WadeMoney/Screens/Dashboard/CategoryDetailScreen.swift
git commit -m "feat(dashboard): add category detail screen"
```

---

### Task 5: `CategoryBreakdownViewModel`

**Files:**
- Create: `WadeMoney/Screens/Dashboard/CategoryBreakdownViewModel.swift`
- Test: `WadeMoneyTests/CategoryBreakdownViewModelTests.swift` (create)

**Interfaces:**
- Consumes: `LedgerRepository.transactions(from:to:)`, `LedgerRepository.allCategories(includeArchived:)`, `Aggregator.totalsByCategory(_:in:)`, `Won.string(_:)`, `Decimal.doubleValue` (all existing, same as Task 3).
- Produces: `CategoryBreakdownViewModel(repository:period:)`, `.load()`, `.rows: [CategoryBreakdownViewModel.Row]` where `Row` has `id: UUID`, `categoryID: UUID`, `name: String`, `iconName: String`, `colorHex: String`, `amountText: String`, `percentText: String`. Task 6 constructs this and reads `.rows`.

- [ ] **Step 1: Write the failing tests**

Create `WadeMoneyTests/CategoryBreakdownViewModelTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct CategoryBreakdownViewModelTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }
    func makeRepo() throws -> (LedgerRepository, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        return (LedgerRepository(context: container.mainContext), container)
    }
    func catID(_ repo: LedgerRepository, _ name: String) throws -> UUID {
        try repo.allCategories(includeArchived: false).first { $0.name == name }!.id
    }

    @Test func ranksAllCategoriesByAmountDescendingWithPercent() throws {
        let (repo, container) = try makeRepo()
        let food = try catID(repo, "식비"); let cafe = try catID(repo, "카페")
        try repo.addTransaction(amount: 300_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))
        try repo.addTransaction(amount: 100_000, type: .expense, categoryID: cafe, memo: nil, date: date(2026, 7, 6))

        let period = Period(kind: .month, start: date(2026, 7, 1), end: date(2026, 8, 1))
        let vm = CategoryBreakdownViewModel(repository: repo, period: period)
        vm.load()

        #expect(vm.rows.count == 2)
        #expect(vm.rows[0].name == "식비")
        #expect(vm.rows[0].amountText == "300,000")
        #expect(vm.rows[0].percentText == "75%")
        #expect(vm.rows[1].name == "카페")
        #expect(vm.rows[1].percentText == "25%")
        _ = container
    }

    @Test func excludesTransactionsOutsideThePeriod() throws {
        let (repo, container) = try makeRepo()
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 50_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 6, 30))
        try repo.addTransaction(amount: 70_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))

        let period = Period(kind: .month, start: date(2026, 7, 1), end: date(2026, 8, 1))
        let vm = CategoryBreakdownViewModel(repository: repo, period: period)
        vm.load()

        #expect(vm.rows.count == 1)
        #expect(vm.rows[0].amountText == "70,000")
        _ = container
    }

    @Test func emptyPeriodProducesNoRows() throws {
        let (repo, container) = try makeRepo()
        let period = Period(kind: .month, start: date(2026, 7, 1), end: date(2026, 8, 1))
        let vm = CategoryBreakdownViewModel(repository: repo, period: period)
        vm.load()
        #expect(vm.rows.isEmpty)
        _ = container
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/CategoryBreakdownViewModelTests`
Expected: FAIL to build — `cannot find 'CategoryBreakdownViewModel' in scope`.

- [ ] **Step 3: Create `CategoryBreakdownViewModel`**

Create `WadeMoney/Screens/Dashboard/CategoryBreakdownViewModel.swift`:

```swift
import Foundation
import Observation
import WadeMoneyCore

@MainActor
@Observable
final class CategoryBreakdownViewModel {
    struct Row: Identifiable {
        let id: UUID
        let categoryID: UUID
        let name: String
        let iconName: String
        let colorHex: String
        let amountText: String
        let percentText: String
    }

    private let repository: LedgerRepository
    private let period: Period
    private(set) var rows: [Row] = []

    init(repository: LedgerRepository, period: Period) {
        self.repository = repository
        self.period = period
    }

    func load() {
        let txns = (try? repository.transactions(from: period.start, to: period.end)) ?? []
        let categories = (try? repository.allCategories(includeArchived: true)) ?? []
        let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        let totals = Aggregator.totalsByCategory(txns, in: period)
        let grandTotal = totals.reduce(Decimal(0)) { $0 + $1.total }

        rows = totals.compactMap { total -> Row? in
            guard let categoryID = total.categoryID, let category = byID[categoryID] else { return nil }
            let pct = grandTotal > 0 ? Int(((total.total / grandTotal).doubleValue * 100).rounded()) : 0
            return Row(
                id: category.id,
                categoryID: category.id,
                name: category.name,
                iconName: category.iconName,
                colorHex: category.colorHex,
                amountText: Won.string(total.total),
                percentText: "\(pct)%"
            )
        }
    }
}
```

(`Aggregator.totalsByCategory` already sorts descending by total, so `rows` comes out ranked without extra sorting here.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/CategoryBreakdownViewModelTests`
Expected: PASS, 3 tests.

- [ ] **Step 5: Run the full unit test suite to check for regressions**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: PASS, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add WadeMoney/Screens/Dashboard/CategoryBreakdownViewModel.swift WadeMoneyTests/CategoryBreakdownViewModelTests.swift
git commit -m "feat(dashboard): add category breakdown view model"
```

---

### Task 6: `CategoryBreakdownScreen` + wire up the "카테고리 비중" card tap + full-flow verification

**Files:**
- Create: `WadeMoney/Screens/Dashboard/CategoryBreakdownScreen.swift`
- Modify: `WadeMoney/Screens/Dashboard/DashboardScreen.swift`

**Interfaces:**
- Consumes: `CategoryBreakdownViewModel(repository:period:)` + `.rows` (Task 5). `CategoryDetailScreen(categoryID:categoryName:categoryIconName:categoryColorHex:period:periodLabel:repository:)` (Task 4). `DashboardViewModel.DashboardDisplay.period` (Task 2).

This task has no new pure logic (it's a SwiftUI list view over an already-tested view model plus navigation wiring), so there's no RED/GREEN unit cycle — verify with build + full test suite + a manual screenshot of the whole tap flow.

- [ ] **Step 1: Create `CategoryBreakdownScreen`**

Create `WadeMoney/Screens/Dashboard/CategoryBreakdownScreen.swift`:

```swift
import SwiftUI
import WadeMoneyCore

struct CategoryBreakdownScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CategoryBreakdownViewModel?
    @State private var selectedRow: CategoryBreakdownViewModel.Row?
    @State private var showDetail = false

    let period: Period
    let periodLabel: String
    let repository: LedgerRepository

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WadeSpacing.cardGap) {
                backRow
                Text("\(periodLabel) 카테고리별 지출")
                    .font(WadeFont.pretendard(22, weight: .heavy))
                    .foregroundStyle(WadeColors.ink(scheme))
                if let vm = viewModel {
                    if vm.rows.isEmpty {
                        emptyState
                    } else {
                        listCard(vm)
                    }
                }
            }
            .padding(.horizontal, WadeSpacing.screenH)
            .padding(.top, WadeSpacing.contentTop)
            .padding(.bottom, WadeSpacing.contentBottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WadeColors.bg(scheme))
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $showDetail) {
            if let row = selectedRow {
                CategoryDetailScreen(
                    categoryID: row.categoryID,
                    categoryName: row.name,
                    categoryIconName: row.iconName,
                    categoryColorHex: row.colorHex,
                    period: period,
                    periodLabel: periodLabel,
                    repository: repository
                )
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = CategoryBreakdownViewModel(repository: repository, period: period)
                vm.load()
                viewModel = vm
            }
        }
    }

    private var backRow: some View {
        Button { dismiss() } label: {
            HStack(spacing: 3) { Icon("chevron_left", size: 18); Text("대시보드").font(WadeFont.pretendard(14, weight: .semibold)) }
                .foregroundStyle(WadeColors.ink2(scheme))
        }.buttonStyle(.plain)
    }

    private func listCard(_ vm: CategoryBreakdownViewModel) -> some View {
        VStack(spacing: 0) {
            ForEach(vm.rows) { row in
                Button {
                    selectedRow = row
                    showDetail = true
                } label: { rowView(row) }
                .buttonStyle(.plain)
                if row.id != vm.rows.last?.id {
                    Divider().overlay(WadeColors.line(scheme)).padding(.leading, 16)
                }
            }
        }
        .background(WadeColors.card(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.listCard, style: .continuous))
        .shadow(color: WadeShadow.list(scheme).color, radius: WadeShadow.list(scheme).radius, y: WadeShadow.list(scheme).y)
    }

    private func rowView(_ row: CategoryBreakdownViewModel.Row) -> some View {
        HStack(spacing: 13) {
            Icon(row.iconName, size: 21).foregroundStyle(Color(hex: row.colorHex))
                .frame(width: 38, height: 38)
                .background(Color(hex: row.colorHex).opacity(0.13), in: RoundedRectangle(cornerRadius: WadeRadius.iconTile))
            Text(row.name).font(WadeFont.pretendard(14.5, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("₩\(row.amountText)").font(WadeFont.pretendard(14.5, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                Text(row.percentText).font(WadeFont.pretendard(11.5, weight: .bold)).foregroundStyle(WadeColors.ink3(scheme))
            }
            Icon("chevron_right", size: 16, filled: false).foregroundStyle(WadeColors.ink3(scheme))
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .frame(minHeight: 64)
    }

    private var emptyState: some View {
        VStack(spacing: 11) {
            Icon("category", size: 38, filled: false).foregroundStyle(WadeColors.ink3(scheme))
                .frame(width: 74, height: 74)
                .background(WadeColors.card2(scheme), in: Circle())
            Text("이 기간엔 지출이 없어요")
                .font(WadeFont.pretendard(16, weight: .heavy))
                .foregroundStyle(WadeColors.ink2(scheme))
        }
        .frame(maxWidth: .infinity).padding(.top, 64)
    }
}
```

- [ ] **Step 2: Wire the "카테고리 비중" card tap in `DashboardScreen`**

In `WadeMoney/Screens/Dashboard/DashboardScreen.swift`, add three new `@State` properties right after `showReport`:

```swift
    @State private var showReport = false
    @State private var showCategoryBreakdown = false
    @State private var breakdownPeriod: Period?
    @State private var breakdownPeriodLabel: String = ""
    var refreshToken: Int = 0
```

Replace the `DonutCard` line:

```swift
                        DonutCard(total: d.totalText, hasExpense: d.hasExpense, legend: d.donut)
                        TrendCard(bars: d.trend)
```

with:

```swift
                        Button {
                            guard !d.donut.isEmpty else { return }
                            breakdownPeriod = d.period
                            breakdownPeriodLabel = d.periodLabel
                            showCategoryBreakdown = true
                        } label: {
                            DonutCard(total: d.totalText, hasExpense: d.hasExpense, legend: d.donut)
                        }
                        .buttonStyle(.plain)
                        TrendCard(bars: d.trend)
```

And add a second `navigationDestination` right after the existing one:

```swift
            .navigationDestination(isPresented: $showReport) { AIReportScreen() }
            .navigationDestination(isPresented: $showCategoryBreakdown) {
                if let period = breakdownPeriod {
                    CategoryBreakdownScreen(period: period, periodLabel: breakdownPeriodLabel, repository: LedgerRepository(context: modelContext))
                }
            }
```

- [ ] **Step 3: Build the whole target**

Run: `xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run the full unit test suite**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: PASS, 0 failures.

- [ ] **Step 5: Visually verify the full tap flow on simulator**

Add a temporary screenshot test to `WadeMoneyUITests/CoreFlowUITests.swift`, right after the `button(containing:in:)` helper method:

```swift
    func testTempCategoryDetailFlowScreenshot() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["한눈에"].waitForExistence(timeout: 15))

        // 시드 데이터만으로는 카테고리 비중 카드가 비어있을 수 있으니 지출을 하나 만든다.
        let fab = app.buttons["addTransaction"]
        XCTAssertTrue(fab.waitForExistence(timeout: 5))
        fab.tap()
        for key in ["5", "0", "0", "0", "0"] { app.buttons[key].tap() }
        button(containing: "식비", in: app).tap()
        let memoField = app.textFields["메모 (어떤 내역인가요?)"]
        XCTAssertTrue(memoField.waitForExistence(timeout: 3))
        memoField.tap()
        memoField.typeText("점심")
        button(containing: "저장하기", in: app).tap()
        XCTAssertTrue(app.staticTexts["한눈에"].waitForExistence(timeout: 5))

        let donutTitle = app.staticTexts["카테고리 비중"]
        XCTAssertTrue(donutTitle.waitForExistence(timeout: 5))
        donutTitle.tap()

        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "카테고리별 지출")).firstMatch.waitForExistence(timeout: 5), "카테고리 순위 목록으로 이동하지 않음")
        let attachment1 = XCTAttachment(screenshot: app.screenshot())
        attachment1.lifetime = .keepAlways
        attachment1.name = "categoryBreakdownList"
        add(attachment1)

        let foodRow = app.staticTexts["식비"]
        XCTAssertTrue(foodRow.waitForExistence(timeout: 5))
        foodRow.tap()

        XCTAssertTrue(app.staticTexts["최근 거래"].waitForExistence(timeout: 5), "카테고리 상세 화면으로 이동하지 않음")
        let attachment2 = XCTAttachment(screenshot: app.screenshot())
        attachment2.lifetime = .keepAlways
        attachment2.name = "categoryDetailScreen"
        add(attachment2)
    }
```

Run it and export the screenshots:

```bash
rm -rf /tmp/wademoney-category-test.xcresult
xcodebuild test -scheme WadeMoneyUITests -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:WadeMoneyUITests/CoreFlowUITests/testTempCategoryDetailFlowScreenshot \
  -resultBundlePath /tmp/wademoney-category-test.xcresult
mkdir -p /tmp/wademoney-category-screens
xcrun xcresulttool export attachments --path /tmp/wademoney-category-test.xcresult --output-path /tmp/wademoney-category-screens
```

Read both exported PNGs (path printed by the export command) with the Read tool. Confirm:
- `categoryBreakdownList`: shows a ranked list with at least "식비" and its amount/percent, chevron on each row.
- `categoryDetailScreen`: shows the "식비" summary card (icon, name, period label, amount, percent) and a "최근 거래" list containing the "점심" transaction just added.

Then remove the temporary test method from `WadeMoneyUITests/CoreFlowUITests.swift` and confirm `git diff -- WadeMoneyUITests/CoreFlowUITests.swift` is empty.

- [ ] **Step 6: Run the existing E2E suite to check for regressions**

Run: `xcodebuild test -scheme WadeMoneyUITests -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyUITests/CoreFlowUITests`
Expected: PASS, both `testQuickAddExpenseFlowUpdatesHistory` and `testTabNavigationAndSettings`.

- [ ] **Step 7: Commit**

```bash
git add WadeMoney/Screens/Dashboard/CategoryBreakdownScreen.swift WadeMoney/Screens/Dashboard/DashboardScreen.swift
git commit -m "feat(dashboard): add category breakdown screen, wire up donut card tap"
```
