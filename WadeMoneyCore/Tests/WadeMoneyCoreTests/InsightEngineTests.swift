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
