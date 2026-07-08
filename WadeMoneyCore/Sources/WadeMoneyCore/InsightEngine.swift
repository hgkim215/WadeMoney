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
}
