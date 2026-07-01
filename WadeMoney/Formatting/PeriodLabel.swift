import Foundation
import WadeMoneyCore

enum PeriodLabel {
    static func text(kind: PeriodKind, period: Period, now: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: period.start)
        switch kind {
        case .day:
            let today = calendar.isDate(period.start, inSameDayAs: now)
            return "\(c.month ?? 0)월 \(c.day ?? 0)일" + (today ? " (오늘)" : "")
        case .month:
            return "\(c.year ?? 0)년 \(c.month ?? 0)월"
        case .year:
            return "\(c.year ?? 0)년"
        }
    }
}
