import Foundation

public struct BudgetSnapshot: Equatable, Sendable {
    /// A budget-month is labeled by the calendar year-month of its START date. With a non-default monthStartDay, e.g. the Jun-25→Jul-25 period is labeled YearMonth(year: …, month: 6). The persistence layer must set effectiveMonth from the period's start month.
    public let effectiveMonth: YearMonth
    public let amount: Decimal

    public init(effectiveMonth: YearMonth, amount: Decimal) {
        self.effectiveMonth = effectiveMonth
        self.amount = amount
    }
}

public struct BudgetBook: Sendable {
    private let snapshots: [BudgetSnapshot]   // effectiveMonth 오름차순

    public init(_ snapshots: [BudgetSnapshot]) {
        self.snapshots = snapshots.sorted { $0.effectiveMonth < $1.effectiveMonth }
    }

    /// 해당 월 이하 중 가장 최근 effectiveMonth의 금액.
    public func amount(for ym: YearMonth) -> Decimal? {
        snapshots.last { $0.effectiveMonth <= ym }?.amount
    }

    public func monthlyAmount(on date: Date, calc: PeriodCalculator) -> Decimal? {
        amount(for: yearMonth(ofPeriodStart: calc.period(.month, containing: date), calc: calc))
    }

    public func dailyAmount(on date: Date, calc: PeriodCalculator) -> Decimal? {
        let period = calc.period(.month, containing: date)
        guard let monthly = amount(for: yearMonth(ofPeriodStart: period, calc: calc)) else { return nil }
        let days = calc.dayCount(of: period)
        guard days > 0 else { return nil }
        return monthly / Decimal(days)
    }

    /// 그 해 12개 예산월 금액의 합. 스냅샷 없는 월은 0으로 취급. 모든 월이 없으면 nil.
    public func yearAmount(on date: Date, calc: PeriodCalculator) -> Decimal? {
        let year = calc.period(.year, containing: date)
        var total = Decimal(0)
        var any = false
        var cursor = year.start
        while cursor < year.end {
            let ym = YearMonth(
                year: calc.calendar.component(.year, from: cursor),
                month: calc.calendar.component(.month, from: cursor)
            )
            if let a = amount(for: ym) {
                total += a
                any = true
            }
            cursor = calc.calendar.date(byAdding: .month, value: 1, to: cursor)!
        }
        return any ? total : nil
    }

    private func yearMonth(ofPeriodStart period: Period, calc: PeriodCalculator) -> YearMonth {
        YearMonth(
            year: calc.calendar.component(.year, from: period.start),
            month: calc.calendar.component(.month, from: period.start)
        )
    }
}
