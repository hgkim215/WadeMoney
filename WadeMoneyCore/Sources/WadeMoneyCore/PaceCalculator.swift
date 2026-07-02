import Foundation

public struct PaceResult: Equatable, Sendable {
    public let currentCumulative: Decimal
    public let priorCumulative: Decimal
    public let deltaRatio: Decimal?   // nil = 비교 불가

    public init(currentCumulative: Decimal, priorCumulative: Decimal, deltaRatio: Decimal?) {
        self.currentCumulative = currentCumulative
        self.priorCumulative = priorCumulative
        self.deltaRatio = deltaRatio
    }

    public var isComparable: Bool { deltaRatio != nil }
}

public struct CategoryPaceItem: Equatable, Sendable {
    public let categoryID: UUID?
    public let currentCumulative: Decimal
    public let priorCumulative: Decimal
    public let deltaRatio: Decimal?

    public init(categoryID: UUID?, currentCumulative: Decimal, priorCumulative: Decimal, deltaRatio: Decimal?) {
        self.categoryID = categoryID
        self.currentCumulative = currentCumulative
        self.priorCumulative = priorCumulative
        self.deltaRatio = deltaRatio
    }
}

public struct PaceCalculator: Sendable {
    private let calc: PeriodCalculator

    public init(calc: PeriodCalculator) {
        self.calc = calc
    }

    public func pace(
        kind: PeriodKind,
        containing date: Date,
        asOf now: Date,
        txns: [TransactionRecord]
    ) -> PaceResult {
        let current = calc.period(kind, containing: date)
        let d = calc.daysElapsed(in: current, asOf: now)

        let currentEnd = calc.calendar.date(byAdding: .day, value: d, to: current.start)!
        let currentSum = Aggregator.totalExpense(txns, from: current.start, to: currentEnd)

        let prior = calc.previous(current)
        let priorLength = calc.dayCount(of: prior)
        // 진행 중이면 같은 경과일까지만 비교, 이미 끝난 기간이면 이전 기간 전체와 비교한다
        // (예: 완료된 2월(28일)을 1월 1~28일로 자르면 1월 말 지출이 빠져 증가율이 과장된다).
        let priorD = now >= current.end ? priorLength : min(d, priorLength)
        let priorEnd = calc.calendar.date(byAdding: .day, value: priorD, to: prior.start)!
        let priorSum = Aggregator.totalExpense(txns, from: prior.start, to: priorEnd)

        let ratio: Decimal? = priorSum == 0 ? nil : (currentSum - priorSum) / priorSum
        return PaceResult(currentCumulative: currentSum, priorCumulative: priorSum, deltaRatio: ratio)
    }
}

extension PaceCalculator {
    /// 카테고리별 동일시점 비교. 현재·이전 구간 중 하나라도 지출이 있는 카테고리만 포함, currentCumulative 내림차순.
    public func categoryPace(
        kind: PeriodKind,
        containing date: Date,
        asOf now: Date,
        txns: [TransactionRecord]
    ) -> [CategoryPaceItem] {
        let current = calc.period(kind, containing: date)
        let d = calc.daysElapsed(in: current, asOf: now)
        let currentEnd = calc.calendar.date(byAdding: .day, value: d, to: current.start)!
        let currentTotals = Aggregator.totalsByCategory(txns, from: current.start, to: currentEnd)

        let prior = calc.previous(current)
        let priorLength = calc.dayCount(of: prior)
        // pace()와 동일한 규칙: 끝난 기간은 이전 기간 전체와 비교.
        let priorD = now >= current.end ? priorLength : min(d, priorLength)
        let priorEnd = calc.calendar.date(byAdding: .day, value: priorD, to: prior.start)!
        let priorTotals = Aggregator.totalsByCategory(txns, from: prior.start, to: priorEnd)

        var byID: [UUID?: (current: Decimal, prior: Decimal)] = [:]
        for t in currentTotals { byID[t.categoryID, default: (0, 0)].current = t.total }
        for t in priorTotals { byID[t.categoryID, default: (0, 0)].prior = t.total }

        return byID.map { categoryID, sums in
            let ratio: Decimal? = sums.prior == 0 ? nil : (sums.current - sums.prior) / sums.prior
            return CategoryPaceItem(categoryID: categoryID, currentCumulative: sums.current, priorCumulative: sums.prior, deltaRatio: ratio)
        }
        .sorted { $0.currentCumulative > $1.currentCumulative }
    }
}
