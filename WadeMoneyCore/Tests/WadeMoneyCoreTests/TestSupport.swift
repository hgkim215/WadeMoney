import Foundation
@testable import WadeMoneyCore

enum TS {
    /// 결정적 테스트용 UTC 그레고리안 캘린더.
    static var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    /// UTC 자정 기준 날짜.
    static func date(_ y: Int, _ m: Int, _ d: Int, _ hh: Int = 0, _ mm: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = hh; comps.minute = mm
        return utc.date(from: comps)!
    }
}
