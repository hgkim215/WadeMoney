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
        let priorD = min(d, priorLength)
        let priorEnd = calc.calendar.date(byAdding: .day, value: priorD, to: prior.start)!
        let priorSum = Aggregator.totalExpense(txns, from: prior.start, to: priorEnd)

        let ratio: Decimal? = priorSum == 0 ? nil : (currentSum - priorSum) / priorSum
        return PaceResult(currentCumulative: currentSum, priorCumulative: priorSum, deltaRatio: ratio)
    }
}
