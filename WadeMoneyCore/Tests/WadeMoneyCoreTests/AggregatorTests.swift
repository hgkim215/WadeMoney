import Foundation
import Testing
@testable import WadeMoneyCore

struct AggregatorTests {
    let cal = PeriodCalculator(calendar: TS.utc, monthStartDay: 1)
    let food = UUID()
    let cafe = UUID()

    func txns() -> [TransactionRecord] {
        [
            TransactionRecord(amount: 9000, type: .expense, categoryID: food, date: TS.date(2026, 7, 2)),
            TransactionRecord(amount: 4800, type: .expense, categoryID: cafe, date: TS.date(2026, 7, 3)),
            TransactionRecord(amount: 3200, type: .expense, categoryID: cafe, date: TS.date(2026, 7, 4)),
            TransactionRecord(amount: 45000, type: .income, categoryID: nil, date: TS.date(2026, 7, 5)),
            // 구간 밖
            TransactionRecord(amount: 5000, type: .expense, categoryID: food, date: TS.date(2026, 6, 30)),
        ]
    }

    @Test func totalExpenseIgnoresIncomeAndOutOfRange() {
        let p = cal.period(.month, containing: TS.date(2026, 7, 1))
        #expect(Aggregator.totalExpense(txns(), in: p) == 17000)   // 9000+4800+3200
    }

    @Test func totalIncomeSumsIncomeOnly() {
        let p = cal.period(.month, containing: TS.date(2026, 7, 1))
        #expect(Aggregator.totalIncome(txns(), in: p) == 45000)
    }

    @Test func totalExpenseByExplicitInterval() {
        // 7/1 00:00 ~ 7/4 00:00 → 7/2, 7/3만 포함
        let sum = Aggregator.totalExpense(txns(), from: TS.date(2026, 7, 1), to: TS.date(2026, 7, 4))
        #expect(sum == 13800)   // 9000 + 4800
    }

    @Test func totalsByCategoryGroupsAndSortsDescending() {
        let p = cal.period(.month, containing: TS.date(2026, 7, 1))
        let totals = Aggregator.totalsByCategory(txns(), in: p)
        #expect(totals.count == 2)
        #expect(totals[0] == CategoryTotal(categoryID: food, total: 9000))   // 최대 먼저
        #expect(totals[1] == CategoryTotal(categoryID: cafe, total: 8000))   // 4800+3200
    }
}
