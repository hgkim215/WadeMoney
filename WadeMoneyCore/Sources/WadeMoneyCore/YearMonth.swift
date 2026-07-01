public struct YearMonth: Equatable, Comparable, Hashable, Sendable {
    public let year: Int
    public let month: Int   // 1...12

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    public static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        return lhs.month < rhs.month
    }

    /// 지정한 개월 수를 더한 YearMonth. 음수 가능.
    public func adding(months: Int) -> YearMonth {
        let zeroBased = year * 12 + (month - 1) + months
        let y = Int((Double(zeroBased) / 12.0).rounded(.down))
        let m = zeroBased - y * 12 + 1
        return YearMonth(year: y, month: m)
    }
}
