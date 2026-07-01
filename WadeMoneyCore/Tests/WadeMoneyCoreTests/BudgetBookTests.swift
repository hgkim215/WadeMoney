import Foundation
import Testing
@testable import WadeMoneyCore

struct BudgetBookTests {
    let cal = PeriodCalculator(calendar: TS.utc, monthStartDay: 1)

    // 2026-05부터 100만, 2026-07부터 130만
    var book: BudgetBook {
        BudgetBook([
            BudgetSnapshot(effectiveMonth: YearMonth(year: 2026, month: 5), amount: 1_000_000),
            BudgetSnapshot(effectiveMonth: YearMonth(year: 2026, month: 7), amount: 1_300_000),
        ])
    }

    @Test func picksMostRecentEffectiveSnapshot() {
        #expect(book.amount(for: YearMonth(year: 2026, month: 6)) == 1_000_000)
        #expect(book.amount(for: YearMonth(year: 2026, month: 7)) == 1_300_000)
        #expect(book.amount(for: YearMonth(year: 2026, month: 9)) == 1_300_000)
    }

    @Test func returnsNilBeforeFirstSnapshot() {
        #expect(book.amount(for: YearMonth(year: 2026, month: 4)) == nil)
    }

    @Test func monthlyAmountResolvesByPeriodStart() {
        #expect(book.monthlyAmount(on: TS.date(2026, 7, 15), calc: cal) == 1_300_000)
        #expect(book.monthlyAmount(on: TS.date(2026, 6, 2), calc: cal) == 1_000_000)
    }

    @Test func dailyAmountDividesByDaysInMonth() {
        // 7월(31일) 130만 → 일예산 = 1_300_000 / 31
        let daily = book.dailyAmount(on: TS.date(2026, 7, 15), calc: cal)!
        #expect(daily == Decimal(1_300_000) / Decimal(31))
    }

    @Test func yearAmountSumsMonthlySnapshots() {
        // 2026: 1~4월 없음(nil→0 취급), 5·6월 100만, 7~12월 130만
        // = 2*100만 + 6*130만 = 200만 + 780만 = 980만
        let y = book.yearAmount(on: TS.date(2026, 7, 15), calc: cal)!
        #expect(y == 9_800_000)
    }
}
