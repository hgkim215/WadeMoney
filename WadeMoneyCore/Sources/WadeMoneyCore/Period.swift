import Foundation

public enum PeriodKind: Sendable, Equatable {
    case day
    case month
    case year
}

public struct Period: Equatable, Sendable {
    public let kind: PeriodKind
    public let start: Date   // inclusive
    public let end: Date     // exclusive

    public init(kind: PeriodKind, start: Date, end: Date) {
        self.kind = kind
        self.start = start
        self.end = end
    }
}

public struct PeriodCalculator: Sendable {
    public let calendar: Calendar
    public let monthStartDay: Int   // 1...28

    public init(calendar: Calendar, monthStartDay: Int = 1) {
        self.calendar = calendar
        self.monthStartDay = min(max(monthStartDay, 1), 28)
    }

    public func period(_ kind: PeriodKind, containing date: Date) -> Period {
        switch kind {
        case .day:   return dayPeriod(containing: date)
        case .month: return monthPeriod(containing: date)
        case .year:  return yearPeriod(containing: date)
        }
    }

    public func period(_ kind: PeriodKind, offset n: Int, from date: Date) -> Period {
        let base = period(kind, containing: date)
        let component: Calendar.Component = {
            switch kind {
            case .day: return .day
            case .month: return .month
            case .year: return .year
            }
        }()
        let shifted = calendar.date(byAdding: component, value: n, to: base.start)!
        return period(kind, containing: shifted)
    }

    public func previous(_ p: Period) -> Period {
        period(p.kind, offset: -1, from: p.start)
    }

    public func dayCount(of p: Period) -> Int {
        calendar.dateComponents([.day], from: p.start, to: p.end).day ?? 0
    }

    /// 구간 시작부터 now가 속한 날까지 경과 일수(당일 포함). 구간 이전이면 0, 구간 종료 이후면 전체 길이.
    public func daysElapsed(in p: Period, asOf now: Date) -> Int {
        if now < p.start { return 0 }
        if now >= p.end { return dayCount(of: p) }
        let startDay = calendar.startOfDay(for: p.start)
        let nowDay = calendar.startOfDay(for: now)
        let diff = calendar.dateComponents([.day], from: startDay, to: nowDay).day ?? 0
        return diff + 1
    }

    // MARK: - Private

    private func dayPeriod(containing date: Date) -> Period {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return Period(kind: .day, start: start, end: end)
    }

    private func monthPeriod(containing date: Date) -> Period {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        var startComps = DateComponents()
        startComps.year = comps.year
        startComps.month = comps.month
        startComps.day = monthStartDay
        var start = calendar.startOfDay(for: calendar.date(from: startComps)!)
        if (comps.day ?? 1) < monthStartDay {
            start = calendar.date(byAdding: .month, value: -1, to: start)!
        }
        let end = calendar.date(byAdding: .month, value: 1, to: start)!
        return Period(kind: .month, start: start, end: end)
    }

    private func yearPeriod(containing date: Date) -> Period {
        let m = monthPeriod(containing: date)
        let startYear = calendar.component(.year, from: m.start)
        var janComps = DateComponents()
        janComps.year = startYear
        janComps.month = 1
        janComps.day = monthStartDay
        let start = calendar.startOfDay(for: calendar.date(from: janComps)!)
        let end = calendar.date(byAdding: .year, value: 1, to: start)!
        return Period(kind: .year, start: start, end: end)
    }
}
