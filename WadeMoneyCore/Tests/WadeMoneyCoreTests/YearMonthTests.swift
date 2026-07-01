import Testing
@testable import WadeMoneyCore

struct YearMonthTests {
    @Test func comparesByYearThenMonth() {
        #expect(YearMonth(year: 2026, month: 3) < YearMonth(year: 2026, month: 7))
        #expect(YearMonth(year: 2025, month: 12) < YearMonth(year: 2026, month: 1))
        #expect(!(YearMonth(year: 2026, month: 7) < YearMonth(year: 2026, month: 7)))
    }

    @Test func addingMonthsRollsOverYear() {
        #expect(YearMonth(year: 2026, month: 11).adding(months: 3) == YearMonth(year: 2027, month: 2))
        #expect(YearMonth(year: 2026, month: 1).adding(months: -1) == YearMonth(year: 2025, month: 12))
        #expect(YearMonth(year: 2026, month: 7).adding(months: 0) == YearMonth(year: 2026, month: 7))
    }
}
