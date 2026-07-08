# AI 소비 리포트 인사이트 개선 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** AI 리포트에 결정적 인사이트 엔진(6종 후보, 자격 규칙, 최대 3개)을 추가하고, 예상 지출을 일회성 분리로 안정화하며, AI 프롬프트 재료를 확장하고, 카드 폭 버그를 고친다.

**Architecture:** 인사이트/예측은 WadeMoneyCore 순수 함수로 계산(TDD), ViewModel이 텍스트 포매팅, Foundation Models는 주어진 수치만 인용해 작문. 스펙: `docs/superpowers/specs/2026-07-09-ai-report-insights-design.md`.

**Tech Stack:** Swift / SwiftUI / SwiftData / FoundationModels / Swift Testing (@Test, #expect)

## Global Constraints

- 커밋은 main에 직접, 트레일러 `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` 필수.
- `docs/design/app-design-specification-analysis/` 하위는 절대 스테이징하지 않는다 (사용자 로컬 산출물).
- 테스트 시뮬레이터는 **iPhone 17e** (`platform=iOS Simulator,name=iPhone 17e`).
- Core 테스트는 `swift test --package-path WadeMoneyCore`, 앱 테스트는 `xcodebuild test -scheme WadeMoney`.
- SourceKit의 "No such module 'WadeMoneyCore'/'Testing'" 진단은 스테일 인덱스 노이즈 — 무시하고 실제 빌드 결과만 믿는다.
- 신규 파일은 WadeMoneyCore(SwiftPM) 안에만 생성 — xcodegen 재생성 불필요. 앱 타깃에는 새 파일을 만들지 않는다.
- 모델(FM)은 절대 숫자를 계산/생성하지 않는다 — 모든 수치는 Swift에서 계산해 텍스트로 전달.
- 한국어 카피는 스펙의 문장을 글자 그대로 사용한다 (예: "아직 초반이라 예상치가 달라질 수 있어요").
- xcodebuild 출력에서 신규 테스트 이름을 grep으로 확인한다 (stale bundle이 "Executed 0 tests"를 낼 수 있음).

---

### Task 1: Projection 안정화 (일회성 분리) + Repository 연결

**Files:**
- Modify: `WadeMoneyCore/Sources/WadeMoneyCore/Projection.swift`
- Modify: `WadeMoney/Stores/LedgerRepository.swift:208-210`
- Test: `WadeMoneyCore/Tests/WadeMoneyCoreTests/ProjectionTests.swift`

**Interfaces:**
- Consumes: 없음 (기존 `Projection.projectedTotal`은 유지)
- Produces: `Projection.splitOneOffs(amounts: [Decimal]) -> (oneOff: Decimal, routine: Decimal)`, `Projection.stabilizedProjectedTotal(amounts: [Decimal], daysElapsed: Int, daysInPeriod: Int) -> Decimal` — Task 2의 budgetRunway가 `splitOneOffs`를 재사용한다.

- [ ] **Step 1: 실패하는 테스트 작성** — `ProjectionTests.swift`에 추가:

```swift
    // MARK: - stabilizedProjectedTotal (일회성 분리)

    @Test func stabilizedSeparatesOneOffFromRoutine() {
        // 일회성 300만(합의 30% 이상) + 일상 3만×3일 → 300만 + 3만×30 = 390만
        let p = Projection.stabilizedProjectedTotal(
            amounts: [3_000_000, 30_000, 30_000, 30_000], daysElapsed: 3, daysInPeriod: 30)
        #expect(p == 3_900_000)
    }

    @Test func stabilizedSingleExpenseProjectsItself() {
        // 지출 1건 = 합의 100% ≥ 30% → 일회성 → 예상치는 그 금액 그대로
        #expect(Projection.stabilizedProjectedTotal(amounts: [500_000], daysElapsed: 2, daysInPeriod: 30) == 500_000)
    }

    @Test func stabilizedWithoutOneOffMatchesLinear() {
        // 각 25%(< 30%) → 전부 일상 → 기존 선형 외삽과 동일
        let p = Projection.stabilizedProjectedTotal(
            amounts: [100_000, 100_000, 100_000, 100_000], daysElapsed: 10, daysInPeriod: 30)
        #expect(p == 1_200_000)
    }

    @Test func stabilizedThresholdBoundaryCountsAsOneOff() {
        // 30,000은 합 100,000의 정확히 30% → 경계 포함 → 일회성
        let p = Projection.stabilizedProjectedTotal(
            amounts: [30_000, 14_000, 14_000, 14_000, 14_000, 14_000], daysElapsed: 10, daysInPeriod: 30)
        #expect(p == 30_000 + 210_000)
    }

    @Test func stabilizedZeroElapsedReturnsZero() {
        #expect(Projection.stabilizedProjectedTotal(amounts: [10_000], daysElapsed: 0, daysInPeriod: 30) == 0)
    }
```

계산 검증: 첫 테스트 routine = 90,000, 90,000 ÷ 3 × 30 = 900,000 → 3,000,000 + 900,000 = 3,900,000.

- [ ] **Step 2: 실패 확인**

Run: `swift test --package-path WadeMoneyCore --filter ProjectionTests 2>&1 | tail -20`
Expected: FAIL — `stabilizedProjectedTotal` 미정의 컴파일 에러

- [ ] **Step 3: 구현** — `Projection.swift`의 enum 안에 추가:

```swift
    /// 누적 합의 30% 이상을 단독으로 차지하는 지출(일회성)과 나머지(일상)로 분리.
    /// 월초 큰 지출 하나가 선형 외삽으로 달 전체에 곱해지는 왜곡을 막는 기준.
    public static func splitOneOffs(amounts: [Decimal]) -> (oneOff: Decimal, routine: Decimal) {
        let total = amounts.reduce(Decimal(0), +)
        guard total > 0 else { return (0, 0) }
        let threshold = total * 3 / 10
        let oneOff = amounts.filter { $0 >= threshold }.reduce(Decimal(0), +)
        return (oneOff, total - oneOff)
    }

    /// 일회성 지출을 분리한 안정화 예상치: 일회성 실적 + 일상 지출의 선형 외삽.
    public static func stabilizedProjectedTotal(
        amounts: [Decimal], daysElapsed: Int, daysInPeriod: Int
    ) -> Decimal {
        guard daysElapsed > 0 else { return 0 }
        let (oneOff, routine) = splitOneOffs(amounts: amounts)
        return oneOff + routine * Decimal(daysInPeriod) / Decimal(daysElapsed)
    }
```

- [ ] **Step 4: 통과 확인**

Run: `swift test --package-path WadeMoneyCore --filter ProjectionTests 2>&1 | tail -5`
Expected: PASS (기존 2개 + 신규 5개)

- [ ] **Step 5: Repository 연결** — `LedgerRepository.swift`의 projected 계산 교체:

```swift
        // 월초 큰 지출 하나가 달 전체로 외삽되지 않도록 일회성을 분리해 예측한다.
        let projected: Decimal? = (kind == .day)
            ? nil
            : Projection.stabilizedProjectedTotal(
                amounts: txns
                    .filter { $0.type == .expense && !$0.isExcludedFromBudget && $0.date >= period.start && $0.date < period.end }
                    .map(\.amount),
                daysElapsed: elapsed,
                daysInPeriod: calc.dayCount(of: period))
```

- [ ] **Step 6: 앱 테스트 통과 확인** (기존 AIReportViewModelTests의 overBudget 테스트가 계속 성립하는지)

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/AIReportViewModelTests 2>&1 | grep -E "Test Suite|passed|failed" | tail -5`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add WadeMoneyCore/Sources/WadeMoneyCore/Projection.swift WadeMoneyCore/Tests/WadeMoneyCoreTests/ProjectionTests.swift WadeMoney/Stores/LedgerRepository.swift
git commit -m "feat(core): stabilize projection by separating one-off expenses

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: InsightEngine — 예산·지출 인사이트 3종 (runway / largest / pace)

**Files:**
- Create: `WadeMoneyCore/Sources/WadeMoneyCore/InsightEngine.swift`
- Test (Create): `WadeMoneyCore/Tests/WadeMoneyCoreTests/InsightEngineTests.swift`

**Interfaces:**
- Consumes: `Projection.splitOneOffs` (Task 1), `PeriodCalculator`, `Aggregator.totalExpense(_:from:to:)`, `TransactionRecord`
- Produces: `public enum Insight` (6 케이스 전부 이 태스크에서 선언), `public struct InsightEngine { init(calc: PeriodCalculator); func insights(txns:period:asOf:budget:maxCount:) -> [Insight] }` — Task 3이 나머지 3종 구현을 채우고, Task 4의 VM이 소비한다.

- [ ] **Step 1: 실패하는 테스트 작성** — `InsightEngineTests.swift` 생성:

```swift
import Foundation
import Testing
@testable import WadeMoneyCore

struct InsightEngineTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    var calc: PeriodCalculator { PeriodCalculator(calendar: utc, monthStartDay: 1) }
    var engine: InsightEngine { InsightEngine(calc: calc) }

    func date(_ y: Int, _ m: Int, _ d: Int, _ hh: Int = 12) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d; comps.hour = hh
        return utc.date(from: comps)!
    }
    func expense(_ amount: Decimal, _ m: Int, _ d: Int, category: UUID? = nil, memo: String? = nil,
                 excluded: Bool = false) -> TransactionRecord {
        TransactionRecord(amount: amount, type: .expense, categoryID: category, memo: memo,
                          date: date(2026, m, d), isExcludedFromBudget: excluded)
    }
    var july: Period { calc.period(.month, containing: date(2026, 7, 15)) }

    // MARK: - budgetRunway

    @Test func runwayEmittedWhenRoutinePaceExhaustsBudgetBeforePeriodEnd() {
        // 예산 30만, 5일간 매일 2만 → 남은 20만 ÷ 2만/일 = 10일 → 7/5 + 10일 = 7/15 소진
        let txns = (1...5).map { expense(20_000, 7, $0) }
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 5, 20), budget: 300_000)
        guard case .budgetRunway(let exhaustDate) = result[0] else {
            Issue.record("runway가 첫 인사이트여야 한다: \(result)"); return
        }
        #expect(utc.isDate(exhaustDate, inSameDayAs: date(2026, 7, 15)))
    }

    @Test func runwayNotEmittedWithoutBudget() {
        let txns = (1...5).map { expense(20_000, 7, $0) }
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 5, 20), budget: nil)
        #expect(!result.contains { if case .budgetRunway = $0 { return true }; return false })
    }

    @Test func runwayNotEmittedWhenExhaustBeyondPeriodEnd() {
        // 하루 1천 → 남은 29.5만 ÷ 1천 = 295일 → 기간 밖 → 미노출
        let txns = (1...5).map { expense(1_000, 7, $0) }
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 5, 20), budget: 300_000)
        #expect(!result.contains { if case .budgetRunway = $0 { return true }; return false })
    }

    @Test func runwayNotEmittedWhenAlreadyOverBudget() {
        let txns = [expense(400_000, 7, 2)]
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 5, 20), budget: 300_000)
        #expect(!result.contains { if case .budgetRunway = $0 { return true }; return false })
    }

    @Test func runwayIgnoresOneOffAndBudgetExcludedExpenses() {
        // 일회성 20만(합의 30%↑)은 일상 페이스에서 제외, 예산 제외 지출은 아예 불포함
        let txns = [expense(200_000, 7, 1)] + (2...6).map { expense(10_000, 7, $0) }
            + [expense(500_000, 7, 3, excluded: true)]
        // 예산반영 누적 25만, 남은 5만. 일상 = 5만/6일 → 6일 후 소진(7/12) < 8/1 → 노출
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 6, 20), budget: 300_000)
        #expect(result.contains { if case .budgetRunway = $0 { return true }; return false })
    }

    // MARK: - largestExpense

    @Test func largestExpenseEmittedWhenShareAtLeastQuarter() {
        let txns = [expense(50_000, 7, 3, memo: "회식"), expense(30_000, 7, 4), expense(20_000, 7, 5)]
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 10), budget: nil)
        guard case .largestExpense(let amount, _, let memo, let share) = result.first(where: {
            if case .largestExpense = $0 { return true }; return false
        }) ?? .noSpendDays(count: 0) else { Issue.record("largestExpense 없음: \(result)"); return }
        #expect(amount == 50_000)
        #expect(memo == "회식")
        #expect(share == Decimal(1) / 2)
    }

    @Test func largestExpenseSuppressedBelowQuarterShare() {
        let txns = (1...5).map { expense(20_000, 7, $0) }   // 각 20% < 25%
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 10), budget: nil)
        #expect(!result.contains { if case .largestExpense = $0 { return true }; return false })
    }

    @Test func largestExpenseRequiresAtLeastThreeExpenses() {
        let txns = [expense(90_000, 7, 3), expense(10_000, 7, 4)]
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 10), budget: nil)
        #expect(!result.contains { if case .largestExpense = $0 { return true }; return false })
    }

    // MARK: - dailyAveragePace

    @Test func paceEmittedWhenDailyAverageDeltaAtLeastTenPercent() {
        // 6월 1~10일 하루 1만, 7월 1~10일 하루 1.2만 → +20%
        let txns = (1...10).map { expense(10_000, 6, $0) } + (1...10).map { expense(12_000, 7, $0) }
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 10, 20), budget: nil)
        guard case .dailyAveragePace(let avg, let delta) = result.first(where: {
            if case .dailyAveragePace = $0 { return true }; return false
        }) ?? .noSpendDays(count: 0) else { Issue.record("pace 없음: \(result)"); return }
        #expect(avg == 12_000)
        #expect(delta == Decimal(2) / 10)
    }

    @Test func paceSuppressedBelowTenPercentDelta() {
        let txns = (1...10).map { expense(10_000, 6, $0) } + (1...10).map { expense(10_500, 7, $0) }
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 10, 20), budget: nil)
        #expect(!result.contains { if case .dailyAveragePace = $0 { return true }; return false })
    }

    @Test func paceSuppressedWithoutPriorMonthData() {
        let txns = (1...10).map { expense(12_000, 7, $0) }
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 10, 20), budget: nil)
        #expect(!result.contains { if case .dailyAveragePace = $0 { return true }; return false })
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: `swift test --package-path WadeMoneyCore --filter InsightEngineTests 2>&1 | tail -20`
Expected: FAIL — `InsightEngine` 미정의 컴파일 에러

- [ ] **Step 3: 구현** — `InsightEngine.swift` 생성 (frequency/weekend/noSpend는 Task 3에서 채우므로 이 단계에서는 nil 반환 스텁):

```swift
import Foundation

/// 소비 내역에서 결정적으로 계산되는 리포트 인사이트. 선언 순서가 노출 우선순위다.
public enum Insight: Equatable, Sendable {
    case budgetRunway(exhaustDate: Date)
    case largestExpense(amount: Decimal, categoryID: UUID?, memo: String?, shareOfTotal: Decimal)
    case dailyAveragePace(currentDailyAverage: Decimal, deltaRatio: Decimal)
    case frequency(categoryID: UUID?, count: Int, total: Decimal, averagePerVisit: Decimal)
    case weekendConcentration(fraction: Decimal)
    case noSpendDays(count: Int)
}

/// 인사이트 후보를 계산하고 자격 규칙으로 필터링해 우선순위 순 최대 maxCount개 반환.
/// 수치 계산은 전부 여기서 — 모델(FM)은 결과 텍스트를 인용만 한다.
public struct InsightEngine: Sendable {
    private let calc: PeriodCalculator
    private var calendar: Calendar { calc.calendar }

    public init(calc: PeriodCalculator) {
        self.calc = calc
    }

    public func insights(
        txns: [TransactionRecord],
        period: Period,
        asOf now: Date,
        budget: Decimal?,
        maxCount: Int = 3
    ) -> [Insight] {
        let d = calc.daysElapsed(in: period, asOf: now)
        guard d > 0 else { return [] }
        let elapsedEnd = calendar.date(byAdding: .day, value: d, to: period.start)!
        let expenses = txns.filter { $0.type == .expense && $0.date >= period.start && $0.date < elapsedEnd }

        var result: [Insight] = []
        if let i = budgetRunway(expenses: expenses, period: period, now: now, budget: budget, daysElapsed: d) { result.append(i) }
        if let i = largestExpense(expenses: expenses) { result.append(i) }
        if let i = dailyAveragePace(txns: txns, period: period, daysElapsed: d) { result.append(i) }
        if let i = frequency(expenses: expenses) { result.append(i) }
        if let i = weekendConcentration(expenses: expenses, daysElapsed: d) { result.append(i) }
        if let i = noSpendDays(expenses: expenses, daysElapsed: d) { result.append(i) }
        return Array(result.prefix(maxCount))
    }

    /// 일상 페이스 기준 예산 소진 예상일. 예산 미설정·이미 초과·기간 내 소진 없음이면 nil.
    private func budgetRunway(
        expenses: [TransactionRecord], period: Period, now: Date, budget: Decimal?, daysElapsed d: Int
    ) -> Insight? {
        guard let budget, budget > 0 else { return nil }
        let budgeted = expenses.filter { !$0.isExcludedFromBudget }.map(\.amount)
        let cumulative = budgeted.reduce(Decimal(0), +)
        let remaining = budget - cumulative
        guard remaining > 0 else { return nil }
        let (_, routine) = Projection.splitOneOffs(amounts: budgeted)
        guard routine > 0 else { return nil }
        let routineDailyAvg = routine / Decimal(d)
        let daysUntilExhaust = Int((remaining / routineDailyAvg).doubleValue.rounded(.up))
        guard let exhaustDate = calendar.date(byAdding: .day, value: daysUntilExhaust, to: calendar.startOfDay(for: now)),
              exhaustDate < period.end else { return nil }
        return .budgetRunway(exhaustDate: exhaustDate)
    }

    /// 총지출의 25% 이상을 차지하는 최대 단일 지출. 지출 3건 미만이면 nil.
    private func largestExpense(expenses: [TransactionRecord]) -> Insight? {
        guard expenses.count >= 3 else { return nil }
        let total = expenses.map(\.amount).reduce(Decimal(0), +)
        guard total > 0, let top = expenses.max(by: { $0.amount < $1.amount }) else { return nil }
        let share = top.amount / total
        guard share >= Decimal(25) / 100 else { return nil }
        return .largestExpense(amount: top.amount, categoryID: top.categoryID, memo: top.memo, shareOfTotal: share)
    }

    /// 하루 평균 지출의 지난달 같은 경과 구간 대비 변화. |변화| < 10%거나 비교 불가면 nil.
    private func dailyAveragePace(txns: [TransactionRecord], period: Period, daysElapsed d: Int) -> Insight? {
        let elapsedEnd = calendar.date(byAdding: .day, value: d, to: period.start)!
        let currentSum = Aggregator.totalExpense(txns, from: period.start, to: elapsedEnd)
        let prior = calc.previous(period)
        let priorD = min(d, calc.dayCount(of: prior))
        guard priorD > 0 else { return nil }
        let priorEnd = calendar.date(byAdding: .day, value: priorD, to: prior.start)!
        let priorSum = Aggregator.totalExpense(txns, from: prior.start, to: priorEnd)
        guard priorSum > 0 else { return nil }
        let currentAvg = currentSum / Decimal(d)
        let priorAvg = priorSum / Decimal(priorD)
        let delta = (currentAvg - priorAvg) / priorAvg
        guard abs(delta) >= Decimal(10) / 100 else { return nil }
        return .dailyAveragePace(currentDailyAverage: currentAvg, deltaRatio: delta)
    }

    private func frequency(expenses: [TransactionRecord]) -> Insight? { nil }

    private func weekendConcentration(expenses: [TransactionRecord], daysElapsed d: Int) -> Insight? { nil }

    private func noSpendDays(expenses: [TransactionRecord], daysElapsed d: Int) -> Insight? { nil }
}
```

- [ ] **Step 4: 통과 확인**

Run: `swift test --package-path WadeMoneyCore --filter InsightEngineTests 2>&1 | tail -5`
Expected: PASS (11개)

- [ ] **Step 5: Commit**

```bash
git add WadeMoneyCore/Sources/WadeMoneyCore/InsightEngine.swift WadeMoneyCore/Tests/WadeMoneyCoreTests/InsightEngineTests.swift
git commit -m "feat(core): add InsightEngine with budget runway, largest expense, daily pace insights

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: InsightEngine — 습관 인사이트 3종 + 우선순위/상한

**Files:**
- Modify: `WadeMoneyCore/Sources/WadeMoneyCore/InsightEngine.swift` (Task 2의 스텁 3개 교체)
- Test: `WadeMoneyCore/Tests/WadeMoneyCoreTests/InsightEngineTests.swift`

**Interfaces:**
- Consumes: Task 2의 `InsightEngine` 골격과 테스트 헬퍼(`expense`, `july`, `engine`)
- Produces: `.frequency`, `.weekendConcentration`, `.noSpendDays` 실제 구현 — Task 4의 VM 포매팅이 소비

- [ ] **Step 1: 실패하는 테스트 작성** — `InsightEngineTests.swift`에 추가 (2026-07-04/05, 11/12는 토/일):

```swift
    // MARK: - frequency

    @Test func frequencyEmittedAtFiveVisits() {
        let cafe = UUID()
        let txns = (1...5).map { expense(4_800, 7, $0, category: cafe) }
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 6), budget: nil)
        guard case .frequency(let cid, let count, let total, let avg) = result.first(where: {
            if case .frequency = $0 { return true }; return false
        }) ?? .noSpendDays(count: 0) else { Issue.record("frequency 없음: \(result)"); return }
        #expect(cid == cafe)
        #expect(count == 5)
        #expect(total == 24_000)
        #expect(avg == 4_800)
    }

    @Test func frequencySuppressedAtFourVisits() {
        let cafe = UUID()
        let txns = (1...4).map { expense(4_800, 7, $0, category: cafe) }
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 6), budget: nil)
        #expect(!result.contains { if case .frequency = $0 { return true }; return false })
    }

    @Test func frequencyTieBrokenByHigherTotal() {
        let cafe = UUID(), food = UUID()
        let txns = (1...5).map { expense(4_800, 7, $0, category: cafe) }
            + (1...5).map { expense(9_000, 7, $0, category: food) }
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 6), budget: nil)
        guard case .frequency(let cid, _, _, _) = result.first(where: {
            if case .frequency = $0 { return true }; return false
        }) ?? .noSpendDays(count: 0) else { Issue.record("frequency 없음"); return }
        #expect(cid == food)
    }

    // MARK: - weekendConcentration

    @Test func weekendConcentrationEmittedWhenHalfOrMoreOnWeekend() {
        // 주말(7/4·5·11·12) 6만 + 평일 4만 = 60% ≥ 50%, 경과 14일
        let txns = [expense(30_000, 7, 4), expense(30_000, 7, 5), expense(40_000, 7, 8)]
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 14, 20), budget: nil)
        guard case .weekendConcentration(let fraction) = result.first(where: {
            if case .weekendConcentration = $0 { return true }; return false
        }) ?? .noSpendDays(count: 0) else { Issue.record("weekend 없음: \(result)"); return }
        #expect(fraction == Decimal(6) / 10)
    }

    @Test func weekendConcentrationSuppressedBeforeFourteenDaysElapsed() {
        let txns = [expense(30_000, 7, 4), expense(30_000, 7, 5), expense(40_000, 7, 8)]
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 13, 20), budget: nil)
        #expect(!result.contains { if case .weekendConcentration = $0 { return true }; return false })
    }

    @Test func weekendConcentrationSuppressedBelowHalf() {
        let txns = [expense(30_000, 7, 4), expense(70_000, 7, 8)]
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 14, 20), budget: nil)
        #expect(!result.contains { if case .weekendConcentration = $0 { return true }; return false })
    }

    // MARK: - noSpendDays

    @Test func noSpendDaysCountsElapsedDaysWithoutExpense() {
        // 7일 경과, 지출은 5개 날짜에만 → 무지출일 2일
        let txns = [1, 2, 3, 4, 5].map { expense(10_000, 7, $0) }
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 7, 20), budget: nil)
        guard case .noSpendDays(let count) = result.first(where: {
            if case .noSpendDays = $0 { return true }; return false
        }) ?? .weekendConcentration(fraction: 0) else { Issue.record("noSpend 없음: \(result)"); return }
        #expect(count == 2)
    }

    @Test func noSpendDaysSuppressedBeforeSevenDaysElapsed() {
        let txns = [expense(10_000, 7, 1)]
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 6, 20), budget: nil)
        #expect(!result.contains { if case .noSpendDays = $0 { return true }; return false })
    }

    @Test func noSpendDaysSuppressedWhenEveryDayHasExpense() {
        let txns = (1...7).map { expense(10_000, 7, $0) }
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 7, 20), budget: nil)
        #expect(!result.contains { if case .noSpendDays = $0 { return true }; return false })
    }

    // MARK: - 우선순위·상한

    @Test func capsAtThreeInsightsInDeclarationOrder() {
        // runway+largest+pace+frequency 동시 자격 → 앞 3개만
        let cafe = UUID()
        let txns = (1...10).map { expense(3_000, 6, $0) }                       // 지난달 (pace 비교용)
            + (1...5).map { expense(4_800, 7, $0, category: cafe) }             // frequency 자격
            + [expense(30_000, 7, 6, memo: "선물")]                             // largest 자격 (30000/54000 ≈ 56%)
        let result = engine.insights(txns: txns, period: july, asOf: date(2026, 7, 10, 20), budget: 60_000)
        #expect(result.count == 3)
        guard case .budgetRunway = result[0] else { Issue.record("0번은 runway: \(result)"); return }
        guard case .largestExpense = result[1] else { Issue.record("1번은 largest: \(result)"); return }
        guard case .dailyAveragePace = result[2] else { Issue.record("2번은 pace: \(result)"); return }
    }
```

계산 확인(capsAtThree): 7월 경과 지출 = 24,000 + 30,000 = 54,000. runway(예산 60,000): 남은 6,000, 일회성 = 30,000(56% ≥ 30%) → 일상 24,000/10일 = 2,400/일 → ceil(6,000/2,400) = 3일 후 = 7/13 < 8/1 → 자격 충족. largest: 30,000/54,000 ≈ 56% ≥ 25% 충족. pace: 6월 1~10일 합 30,000(3,000/일) vs 7월 1~10일 합 54,000(5,400/일) → +80% ≥ 10% 충족. frequency도 자격이지만 4번째라 잘린다.

- [ ] **Step 2: 실패 확인**

Run: `swift test --package-path WadeMoneyCore --filter InsightEngineTests 2>&1 | tail -20`
Expected: 신규 10개 FAIL (스텁이 nil 반환)

- [ ] **Step 3: 구현** — 스텁 3개를 교체:

```swift
    /// 건수 최다 카테고리(5회 이상). 동수면 총액 큰 쪽.
    private func frequency(expenses: [TransactionRecord]) -> Insight? {
        var buckets: [UUID: (count: Int, total: Decimal)] = [:]
        for t in expenses {
            guard let cid = t.categoryID else { continue }
            var b = buckets[cid] ?? (0, 0)
            b.count += 1
            b.total += t.amount
            buckets[cid] = b
        }
        guard let best = buckets.max(by: { ($0.value.count, $0.value.total) < ($1.value.count, $1.value.total) }),
              best.value.count >= 5 else { return nil }
        return .frequency(
            categoryID: best.key,
            count: best.value.count,
            total: best.value.total,
            averagePerVisit: best.value.total / Decimal(best.value.count)
        )
    }

    /// 주말 지출 비중이 50% 이상이면 노출. 경과 14일 미만이면 표본 부족으로 미노출.
    private func weekendConcentration(expenses: [TransactionRecord], daysElapsed d: Int) -> Insight? {
        guard d >= 14 else { return nil }
        let total = expenses.map(\.amount).reduce(Decimal(0), +)
        guard total > 0 else { return nil }
        let weekend = expenses.filter { calendar.isDateInWeekend($0.date) }
            .map(\.amount).reduce(Decimal(0), +)
        let fraction = weekend / total
        guard fraction >= Decimal(1) / 2 else { return nil }
        return .weekendConcentration(fraction: fraction)
    }

    /// 경과일 중 지출 거래가 없는 날 수. 경과 7일 미만이면 미노출.
    private func noSpendDays(expenses: [TransactionRecord], daysElapsed d: Int) -> Insight? {
        guard d >= 7 else { return nil }
        let spendDays = Set(expenses.map { calendar.startOfDay(for: $0.date) })
        let count = d - spendDays.count
        guard count >= 1 else { return nil }
        return .noSpendDays(count: count)
    }
```

- [ ] **Step 4: 통과 확인**

Run: `swift test --package-path WadeMoneyCore --filter InsightEngineTests 2>&1 | tail -5`
Expected: PASS (21개)

- [ ] **Step 5: Commit**

```bash
git add WadeMoneyCore/Sources/WadeMoneyCore/InsightEngine.swift WadeMoneyCore/Tests/WadeMoneyCoreTests/InsightEngineTests.swift
git commit -m "feat(core): add frequency, weekend concentration, no-spend-day insights with priority cap

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: AIReportViewModel — 인사이트 카드 + 예측 신뢰도 캡션

**Files:**
- Modify: `WadeMoney/Screens/Report/AIReportViewModel.swift`
- Test: `WadeMoneyTests/AIReportViewModelTests.swift`

**Interfaces:**
- Consumes: `InsightEngine.insights(txns:period:asOf:budget:maxCount:)` (Task 2·3), `Won.string`
- Produces: `Display.InsightCardItem { id: String, iconName: String, text: String }`, `Display.insightCards: [InsightCardItem]`, `Display.projectionCaption: String?` — Task 6의 화면이 소비. `insightCards`의 `text`는 Task 5의 `insightFacts`로도 쓰인다.

- [ ] **Step 1: 실패하는 테스트 작성** — `AIReportViewModelTests.swift`에 추가:

```swift
    // MARK: - 인사이트 카드·예측 캡션

    @Test func insightCardsIncludeFrequencyWithDeterministicText() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(1_000_000, for: YearMonth(year: 2026, month: 7))
        let cafe = try catID(repo, "카페")
        for day in 1...5 {
            try repo.addTransaction(amount: 4_800, type: .expense, categoryID: cafe, memo: nil, date: date(2026, 7, day, 12))
        }
        let vm = AIReportViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc,
                                    narrator: SpyReportNarrator(result: .failure(AIError())), cache: freshCache())
        await vm.load()
        let cards = try #require(vm.display?.insightCards)
        let freq = try #require(cards.first { $0.id == "frequency" })
        #expect(freq.iconName == "repeat")
        #expect(freq.text == "카페에 5번 · 총 24,000원 · 회당 평균 4,800원")
    }

    @Test func projectionCaptionShownOnlyEarlyInMonth() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(300_000, for: YearMonth(year: 2026, month: 7))
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 50_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 2))

        // 7/5 = 5/31 경과(16%) < 25% → 캡션 노출
        let early = AIReportViewModel(repository: repo, now: date(2026, 7, 5, 12), calendar: utc,
                                       narrator: SpyReportNarrator(result: .failure(AIError())), cache: freshCache())
        await early.load()
        #expect(early.display?.projectionCaption == "아직 초반이라 예상치가 달라질 수 있어요")

        // 7/15 = 15/31 경과(48%) → 캡션 없음
        let mid = AIReportViewModel(repository: repo, now: date(2026, 7, 15, 12), calendar: utc,
                                     narrator: SpyReportNarrator(result: .failure(AIError())), cache: freshCache())
        await mid.load()
        #expect(mid.display?.projectionCaption == nil)
        _ = container
    }
```

첫 테스트 끝에 `_ = container` 추가 (기존 컨벤션).

- [ ] **Step 2: 실패 확인**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/AIReportViewModelTests 2>&1 | grep -E "error|failed" | head -10`
Expected: 컴파일 에러 (`insightCards` 미정의)

- [ ] **Step 3: 구현** — `AIReportViewModel.swift`:

Display에 추가:

```swift
    struct InsightCardItem: Equatable, Identifiable {
        let id: String
        let iconName: String
        let text: String
    }
```

Display 필드에 `let insightCards: [InsightCardItem]`, `let projectionCaption: String?` 추가 (changes 다음, tipSentence 앞).

`load()`에서 `let input = ReportInput(...)` 위에:

```swift
        // 인사이트는 이미 페치한 거래 배열을 재사용해 결정적으로 계산한다 — 추가 DB 조회 없음.
        let insights = InsightEngine(calc: calc).insights(
            txns: txns, period: summary.period, asOf: now, budget: summary.budget)
        let insightCards = insights.map { insightCard($0, byID: byID) }
        let dayCount = calc.dayCount(of: summary.period)
        let projectionCaption: String? =
            (summary.projected != nil && dayCount > 0 && Double(elapsed) / Double(dayCount) < 0.25)
            ? "아직 초반이라 예상치가 달라질 수 있어요" : nil
```

Display 생성에 `insightCards: insightCards, projectionCaption: projectionCaption` 전달.

포매팅 메서드 추가:

```swift
    /// 인사이트 원시 값 → 카드 문장. 수치는 전부 여기서 포매팅되고 AI는 이 문장을 인용만 한다.
    private func insightCard(_ insight: Insight, byID: [UUID: CategoryRef]) -> Display.InsightCardItem {
        func pct(_ ratio: Decimal) -> Int { Int((abs(ratio) * 100).doubleValue.rounded()) }
        switch insight {
        case .budgetRunway(let exhaustDate):
            let c = calendar.dateComponents([.month, .day], from: exhaustDate)
            return .init(id: "runway", iconName: "hourglass_bottom",
                         text: "이 속도면 \(c.month ?? 0)월 \(c.day ?? 0)일쯤 예산이 소진돼요")
        case .largestExpense(let amount, let categoryID, let memo, let share):
            let name = memo?.isEmpty == false ? memo! : (categoryID.flatMap { byID[$0]?.name } ?? "기타")
            return .init(id: "largest", iconName: "payments",
                         text: "가장 큰 지출은 \(name) \(Won.string(amount))원 — 이번 달 지출의 \(pct(share))%예요")
        case .dailyAveragePace(let avg, let delta):
            let up = delta > 0
            return .init(id: "pace", iconName: up ? "trending_up" : "trending_down",
                         text: "하루 평균 \(Won.string(avg))원 쓰고 있어요 — 지난달 같은 시점보다 \(pct(delta))% \(up ? "높아요" : "낮아요")")
        case .frequency(let categoryID, let count, let total, let avgPerVisit):
            let name = categoryID.flatMap { byID[$0]?.name } ?? "기타"
            return .init(id: "frequency", iconName: "repeat",
                         text: "\(name)에 \(count)번 · 총 \(Won.string(total))원 · 회당 평균 \(Won.string(avgPerVisit))원")
        case .weekendConcentration(let fraction):
            return .init(id: "weekend", iconName: "weekend",
                         text: "지출의 \(pct(fraction))%가 주말에 몰려 있어요")
        case .noSpendDays(let count):
            return .init(id: "nospend", iconName: "event_available",
                         text: "이번 달 무지출일이 \(count)일 있었어요")
        }
    }
```

- [ ] **Step 4: 통과 확인**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/AIReportViewModelTests 2>&1 | grep -E "Test Suite|Executed|insightCards|projectionCaption" | tail -8`
Expected: PASS. `grep "insightCardsIncludeFrequency"` 로 신규 테스트가 실제 실행됐는지 확인.

- [ ] **Step 5: Commit**

```bash
git add WadeMoney/Screens/Report/AIReportViewModel.swift WadeMoneyTests/AIReportViewModelTests.swift
git commit -m "feat(report): map insights to deterministic cards with early-month projection caption

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: ReportInput 개편 — 인사이트 사실 전달 + 0% 문장 차단

**Files:**
- Modify: `WadeMoney/AI/AIServices.swift:25-35`
- Modify: `WadeMoney/AI/FoundationModelsAIServices.swift:19-24,86-108`
- Modify: `WadeMoney/Screens/Report/AIReportViewModel.swift` (input 조립 + 캐시 키)
- Test: `WadeMoneyTests/AIReportViewModelTests.swift`

**Interfaces:**
- Consumes: Task 4의 `insightCards` (text가 곧 사실 문자열)
- Produces: `ReportInput.paceDelta: (percentText: String, increased: Bool)?`, `ReportInput.insightFacts: [String]` — 프롬프트와 캐시 키가 이 필드를 사용

- [ ] **Step 1: 실패하는 테스트 작성** — `AIReportViewModelTests.swift`에 추가:

```swift
    // MARK: - AI 입력 품질

    @Test func paceDeltaNilWhenNoPriorMonthComparison() async throws {
        // 지난달 데이터 없음 → deltaRatio nil → paceDelta nil → "0% 감소" 문장 차단
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(300_000, for: YearMonth(year: 2026, month: 7))
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 50_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))

        let spy = SpyReportNarrator(result: .success(ReportNarration(summarySentence: "s", tipSentence: "t")))
        let vm = AIReportViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc, narrator: spy, cache: freshCache())
        await vm.load()
        #expect(spy.lastInput?.paceDelta == nil)
        _ = container
    }

    @Test func insightFactsForwardedToNarrator() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(1_000_000, for: YearMonth(year: 2026, month: 7))
        let cafe = try catID(repo, "카페")
        for day in 1...5 {
            try repo.addTransaction(amount: 4_800, type: .expense, categoryID: cafe, memo: nil, date: date(2026, 7, day, 12))
        }
        let spy = SpyReportNarrator(result: .success(ReportNarration(summarySentence: "s", tipSentence: "t")))
        let vm = AIReportViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc, narrator: spy, cache: freshCache())
        await vm.load()
        let facts = try #require(spy.lastInput?.insightFacts)
        #expect(facts.contains("카페에 5번 · 총 24,000원 · 회당 평균 4,800원"))
        _ = container
    }

    @Test func narrationRegeneratedWhenInsightFactsChange() async throws {
        // 총지출·페이스·최대지출이 전부 같아도 인사이트 구성(주말 집중)이 바뀌면 캐시 미스여야 한다.
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(1_000_000, for: YearMonth(year: 2026, month: 7))
        let food = try catID(repo, "식비")
        // 7/4(토) 40,000 + 7/8(수) 30,000 → 주말 비중 57% ≥ 50% → weekend 인사이트 자격
        try repo.addTransaction(amount: 40_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 4, 12))
        try repo.addTransaction(amount: 30_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 8, 12))

        let spy = SpyReportNarrator(result: .success(ReportNarration(summarySentence: "s", tipSentence: "t")))
        let cache = freshCache()
        await AIReportViewModel(repository: repo, now: date(2026, 7, 14, 20), calendar: utc, narrator: spy, cache: cache).load()
        #expect(spy.callCount == 1)

        // 토요일 지출을 월요일(7/6)로 이동 — 총액·최대지출·무지출일 수는 그대로,
        // 주말 인사이트만 사라진다 → insightFacts만 달라져도 재생성돼야 한다.
        let saturday = try #require(try repo.transactions(filter: .all).first { $0.amount == 40_000 })
        try repo.updateTransaction(id: saturday.id, amount: 40_000, type: .expense,
                                   categoryID: food, memo: nil, date: date(2026, 7, 6, 12))
        await AIReportViewModel(repository: repo, now: date(2026, 7, 14, 20), calendar: utc, narrator: spy, cache: cache).load()
        #expect(spy.callCount == 2)
        _ = container
    }
```

주의: `paceDelta == nil` 비교는 튜플 옵셔널이라 `#expect(spy.lastInput?.paceDelta == nil)`이 컴파일되지 않으면 `#expect(spy.lastInput?.paceDelta?.percentText == nil)`로 쓴다.

- [ ] **Step 2: 실패 확인**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/AIReportViewModelTests 2>&1 | grep -E "error" | head -5`
Expected: 컴파일 에러 (`paceDelta`, `insightFacts` 미정의)

- [ ] **Step 3: 구현**

`AIServices.swift`의 ReportInput 교체:

```swift
struct ReportInput: Sendable {
    let monthLabel: String
    let daysElapsedText: String
    let totalExpenseText: String
    let budgetStatusText: String
    /// nil이면 프롬프트에서 전월 대비 줄을 통째로 생략한다 — "감소 0%" 같은 무의미 문장 차단.
    let paceDelta: (percentText: String, increased: Bool)?
    let projectedTotalText: String
    let topIncrease: (name: String, percentText: String)?
    let topDecrease: (name: String, percentText: String)?
    /// 선정된 인사이트의 결정적 사실 문자열(카드 문장과 동일, 최대 3개). 팁의 근거 재료.
    let insightFacts: [String]
}
```

`FoundationModelsAIServices.swift`:

ReportNarrationOutput 가이드 교체:

```swift
@Generable
struct ReportNarrationOutput {
    @Guide(description: "이번 달 소비 요약 1~2문장. 한국어 존댓말. 총지출과 '주요 발견' 중 가장 눈에 띄는 것 하나를 자연스럽게 엮는다. 입력으로 주어진 수치만 인용하고 새 숫자를 만들지 않는다.")
    var summarySentence: String
    @Guide(description: "'주요 발견' 중 하나에 근거한 실행 가능한 절약 팁 1문장. 한국어 존댓말. 새 숫자를 만들지 않는다.")
    var tipSentence: String
}
```

`narrate(_:)` 프롬프트 조립 교체:

```swift
    func narrate(_ input: ReportInput) async throws -> ReportNarration {
        let session = LanguageModelSession(instructions: aiInstructions)
        var lines = [
            "월: \(input.monthLabel) (\(input.daysElapsedText) 경과)",
            "총지출: \(input.totalExpenseText)원",
            "예산 상태: \(input.budgetStatusText)",
        ]
        // 비교 불가·0%면 줄 자체를 생략 — "감소 0%" 같은 문장이 나올 재료를 주지 않는다.
        if let pace = input.paceDelta {
            lines.append("전월 대비: \(pace.increased ? "증가" : "감소") \(pace.percentText)")
        }
        lines.append("이번 달 예상 지출: \(input.projectedTotalText)원")
        lines.append("가장 많이 늘어난 카테고리: \(input.topIncrease.map { "\($0.name) \($0.percentText)" } ?? "없음")")
        lines.append("가장 많이 줄어든 카테고리: \(input.topDecrease.map { "\($0.name) \($0.percentText)" } ?? "없음")")
        if !input.insightFacts.isEmpty {
            lines.append("주요 발견:")
            lines.append(contentsOf: input.insightFacts.map { "- \($0)" })
        }
        lines.append("위 정보로 요약 문장 1~2개와 절약 팁 1문장을 작성해줘. 요약은 총지출과 가장 눈에 띄는 발견을 엮고, 팁은 주요 발견 중 하나에 근거한 구체적 행동을 제안해줘.")
        let prompt = lines.joined(separator: "\n")
        // 출력은 짧은 문장 2~3개뿐 — 토큰 상한으로 생성 꼬리 지연을 차단한다.
        let output = try await withGenerationTimeout {
            try await session.respond(
                to: prompt,
                generating: ReportNarrationOutput.self,
                options: GenerationOptions(maximumResponseTokens: 256)
            ).content
        }
        return ReportNarration(summarySentence: output.summarySentence, tipSentence: output.tipSentence)
    }
```

`AIReportViewModel.swift`의 input 조립 교체:

```swift
        // 0%·비교 불가 페이스는 문장 재료에서 제외한다.
        let paceDelta: (percentText: String, increased: Bool)? = summary.pace?.deltaRatio.flatMap { ratio in
            guard ratio != 0 else { return nil }
            return ("\(Int((abs(ratio) * 100).doubleValue.rounded()))%", ratio > 0)
        }
        let input = ReportInput(
            monthLabel: monthLabel,
            daysElapsedText: "\(elapsed)일",
            totalExpenseText: Won.string(summary.totalExpense),
            budgetStatusText: overBudget != nil ? "예산 초과 예상 +\(Won.string(overBudget!))원" : "예산 내 예상",
            paceDelta: paceDelta,
            projectedTotalText: summary.projected.map { Won.string($0) } ?? "-",
            topIncrease: topIncrease.map { (name: $0.name, percentText: $0.percentText) },
            topDecrease: topDecrease.map { (name: $0.name, percentText: $0.percentText) },
            insightFacts: insightCards.map(\.text)
        )
```

`narrationCacheKey` 교체:

```swift
    /// 내레이션에 영향을 주는 모든 입력 필드로 캐시 키를 만든다 — 데이터가 바뀌면 키도 바뀐다.
    private static func narrationCacheKey(for input: ReportInput) -> String {
        [
            input.monthLabel, input.daysElapsedText, input.totalExpenseText,
            input.budgetStatusText,
            input.paceDelta.map { "\($0.percentText)|\($0.increased)" } ?? "-",
            input.projectedTotalText,
            input.topIncrease.map { "\($0.name)|\($0.percentText)" } ?? "-",
            input.topDecrease.map { "\($0.name)|\($0.percentText)" } ?? "-",
            input.insightFacts.joined(separator: "\u{1E}"),
        ].joined(separator: "\u{1F}")
    }
```

- [ ] **Step 4: 통과 확인** (전체 앱 단위 테스트 — ReportInput 사용처가 모두 갱신됐는지 컴파일로 검증)

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "Test Suite '.*' (passed|failed)|error:" | tail -10`
Expected: 전부 PASS. `grep "insightFactsForwardedToNarrator"` 로 신규 테스트 실행 확인.

- [ ] **Step 5: Commit**

```bash
git add WadeMoney/AI/AIServices.swift WadeMoney/AI/FoundationModelsAIServices.swift WadeMoney/Screens/Report/AIReportViewModel.swift WadeMoneyTests/AIReportViewModelTests.swift
git commit -m "feat(ai): feed insight facts to report narrator, drop meaningless 0% pace line

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: AIReportScreen — 발견 섹션 + 신뢰도 캡션 + 카드 폭 버그 수정

**Files:**
- Modify: `WadeMoney/Screens/Report/AIReportScreen.swift`

**Interfaces:**
- Consumes: `Display.insightCards`, `Display.projectionCaption` (Task 4)
- Produces: 없음 (말단 뷰)

- [ ] **Step 1: 카드 폭 버그 수정** — `card` 헬퍼에서 `.frame(maxWidth:)`를 배경 앞으로 이동:

```swift
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let sh = WadeShadow.card(scheme)
        // frame이 background보다 먼저 와야 카드 배경이 항상 화면 폭을 채운다 —
        // 뒤에 두면 레이아웃 박스만 넓어지고 배경은 콘텐츠 폭에 머문다.
        return content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(WadeSpacing.cardPadding)
            .background(WadeColors.card(scheme))
            .clipShape(RoundedRectangle(cornerRadius: WadeRadius.card, style: .continuous))
            .shadow(color: sh.color, radius: sh.radius, y: sh.y)
    }
```

`tipCard`도 동일하게 — `.frame(maxWidth: .infinity, alignment: .leading)`을 `.padding(WadeSpacing.cardPadding)` 앞으로 이동하고 기존 마지막 `.frame(...)` 줄 삭제:

```swift
    private func tipCard(_ tip: String, isPlaceholder: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Icon("lightbulb", size: 19).foregroundStyle(WadeColors.primary(scheme))
            SentenceHighlighter.styledText(tip, font: WadeFont.pretendard(13.5), scheme: scheme)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WadeSpacing.cardPadding)
        .background(WadeColors.primarysoft(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.card, style: .continuous))
        .redacted(reason: isPlaceholder ? .placeholder : [])
    }
```

- [ ] **Step 2: 발견 섹션 추가** — body의 `projectionCard(d)` 다음 줄에 삽입:

```swift
                    if !d.insightCards.isEmpty { insightsCard(d) }
```

뷰 추가 (`changesCard` 앞에):

```swift
    private func insightsCard(_ d: AIReportViewModel.Display) -> some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text("이번 달 발견").font(WadeFont.pretendard(13, weight: .bold)).foregroundStyle(WadeColors.ink(scheme))
                ForEach(d.insightCards) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Icon(item.iconName, size: 18).foregroundStyle(WadeColors.primary(scheme))
                            .frame(width: 32, height: 32)
                            .background(WadeColors.primarysoft(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.smallTile))
                        SentenceHighlighter.styledText(item.text, font: WadeFont.pretendard(13.5), scheme: scheme)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
```

- [ ] **Step 3: 신뢰도 캡션** — `projectionCard`의 overBudget 배지 아래에 추가:

```swift
                if let caption = d.projectionCaption {
                    Text(caption).font(WadeFont.pretendard(11.5)).foregroundStyle(WadeColors.ink3(scheme))
                }
```

- [ ] **Step 4: 빌드 확인**

Run: `xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | tail -3`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add WadeMoney/Screens/Report/AIReportScreen.swift
git commit -m "feat(report): add insights section, projection confidence caption, fix card width bug

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: 전체 검증

**Files:** 없음 (검증만)

- [ ] **Step 1: Core 전체 테스트**

Run: `swift test --package-path WadeMoneyCore 2>&1 | tail -3`
Expected: 전부 PASS

- [ ] **Step 2: 앱 전체 단위 테스트**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "Test Suite '.*' (passed|failed)|Executed" | tail -10`
Expected: 전부 PASS. 신규 테스트 이름(`insightCardsIncludeFrequency`, `stabilizedSeparatesOneOff`, `runwayEmittedWhen`) grep으로 실행 확인.

- [ ] **Step 3: UI 테스트**

Run: `xcodebuild test -scheme WadeMoneyUITests -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "Test Suite '.*' (passed|failed)" | tail -3`
Expected: 5/5 PASS

- [ ] **Step 4: 시뮬레이터에서 리포트 화면 스크린샷으로 폭 버그 수정·발견 섹션 육안 확인** (선택적 — 실패 시 무시하지 말고 원인 파악)
