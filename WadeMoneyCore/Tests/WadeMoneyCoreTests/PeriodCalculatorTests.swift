import Foundation
import Testing
@testable import WadeMoneyCore

struct PeriodCalculatorTests {
    let cal = PeriodCalculator(calendar: TS.utc, monthStartDay: 1)

    @Test func monthPeriodIsCalendarMonthWhenStartDayIsOne() {
        let p = cal.period(.month, containing: TS.date(2026, 7, 15))
        #expect(p.start == TS.date(2026, 7, 1))
        #expect(p.end == TS.date(2026, 8, 1))
        #expect(cal.dayCount(of: p) == 31)
    }

    @Test func dayPeriodIsSingleDay() {
        let p = cal.period(.day, containing: TS.date(2026, 7, 15, 14, 20))
        #expect(p.start == TS.date(2026, 7, 15))
        #expect(p.end == TS.date(2026, 7, 16))
        #expect(cal.dayCount(of: p) == 1)
    }

    @Test func yearPeriodIsCalendarYearWhenStartDayIsOne() {
        let p = cal.period(.year, containing: TS.date(2026, 7, 15))
        #expect(p.start == TS.date(2026, 1, 1))
        #expect(p.end == TS.date(2027, 1, 1))
    }

    @Test func customMonthStartDayShiftsBoundaries() {
        let c = PeriodCalculator(calendar: TS.utc, monthStartDay: 25)
        // 7월 10일은 6/25~7/25 구간에 속한다
        let p = c.period(.month, containing: TS.date(2026, 7, 10))
        #expect(p.start == TS.date(2026, 6, 25))
        #expect(p.end == TS.date(2026, 7, 25))
        // 7월 25일은 다음 구간의 시작
        let p2 = c.period(.month, containing: TS.date(2026, 7, 25))
        #expect(p2.start == TS.date(2026, 7, 25))
    }

    @Test func offsetNavigatesPeriods() {
        let base = cal.period(.month, containing: TS.date(2026, 7, 15))
        let prev = cal.period(.month, offset: -1, from: base.start)
        #expect(prev.start == TS.date(2026, 6, 1))
        #expect(prev.end == TS.date(2026, 7, 1))
        let next = cal.period(.month, offset: 1, from: base.start)
        #expect(next.start == TS.date(2026, 8, 1))
    }

    @Test func previousReturnsPrecedingPeriod() {
        let p = cal.period(.month, containing: TS.date(2026, 1, 10))
        let prev = cal.previous(p)
        #expect(prev.start == TS.date(2025, 12, 1))
    }

    @Test func daysElapsedIsInclusiveAndCapped() {
        let p = cal.period(.month, containing: TS.date(2026, 7, 1))
        // 7월 15일 기준 → 1~15일 = 15일
        #expect(cal.daysElapsed(in: p, asOf: TS.date(2026, 7, 15, 23, 0)) == 15)
        // 구간 이전
        #expect(cal.daysElapsed(in: p, asOf: TS.date(2026, 6, 20)) == 0)
        // 구간 종료 이후 → 전체 길이(31)
        #expect(cal.daysElapsed(in: p, asOf: TS.date(2026, 9, 1)) == 31)
    }

    @Test func yearBoundaryWithCustomMonthStartDay() {
        let c = PeriodCalculator(calendar: TS.utc, monthStartDay: 15)
        // Jan 5 2026 falls in the budget-month Dec 15 2025 → Jan 15 2026,
        // so its year period is anchored to Jan 15 2025.
        let p = c.period(.year, containing: TS.date(2026, 1, 5))
        #expect(p.start == TS.date(2025, 1, 15))
        #expect(p.end == TS.date(2026, 1, 15))
    }
}
