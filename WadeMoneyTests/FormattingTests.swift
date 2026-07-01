import Foundation
import Testing
import WadeMoneyCore
@testable import WadeMoney

struct FormattingTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }

    @Test func wonAddsThousandsSeparators() {
        #expect(Won.string(1_300_000) == "1,300,000")
        #expect(Won.string(0) == "0")
        #expect(Won.string(840_000) == "840,000")
    }

    @Test func monthLabel() {
        let calc = PeriodCalculator(calendar: utc, monthStartDay: 1)
        let p = calc.period(.month, containing: date(2026, 7, 15))
        #expect(PeriodLabel.text(kind: .month, period: p, now: date(2026, 7, 15), calendar: utc) == "2026년 7월")
    }

    @Test func dayLabelMarksToday() {
        let calc = PeriodCalculator(calendar: utc, monthStartDay: 1)
        let p = calc.period(.day, containing: date(2026, 7, 15))
        #expect(PeriodLabel.text(kind: .day, period: p, now: date(2026, 7, 15), calendar: utc) == "7월 15일 (오늘)")
        // 다른 날이면 (오늘) 없음
        let p2 = calc.period(.day, containing: date(2026, 7, 10))
        #expect(PeriodLabel.text(kind: .day, period: p2, now: date(2026, 7, 15), calendar: utc) == "7월 10일")
    }

    @Test func yearLabel() {
        let calc = PeriodCalculator(calendar: utc, monthStartDay: 1)
        let p = calc.period(.year, containing: date(2026, 7, 15))
        #expect(PeriodLabel.text(kind: .year, period: p, now: date(2026, 7, 15), calendar: utc) == "2026년")
    }
}
