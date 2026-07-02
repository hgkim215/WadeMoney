import Foundation

public struct CategoryTotal: Equatable, Sendable {
    public let categoryID: UUID?
    public let total: Decimal

    public init(categoryID: UUID?, total: Decimal) {
        self.categoryID = categoryID
        self.total = total
    }
}

public enum Aggregator {
    public static func totalExpense(_ txns: [TransactionRecord], in period: Period) -> Decimal {
        totalExpense(txns, from: period.start, to: period.end)
    }

    public static func totalExpense(_ txns: [TransactionRecord], from start: Date, to end: Date) -> Decimal {
        txns.reduce(Decimal(0)) { acc, t in
            guard t.type == .expense, t.date >= start, t.date < end else { return acc }
            return acc + t.amount
        }
    }

    public static func totalIncome(_ txns: [TransactionRecord], in period: Period) -> Decimal {
        txns.reduce(Decimal(0)) { acc, t in
            guard t.type == .income, t.date >= period.start, t.date < period.end else { return acc }
            return acc + t.amount
        }
    }

    /// 지출만 카테고리별 합계. 합계 내림차순.
    public static func totalsByCategory(_ txns: [TransactionRecord], in period: Period) -> [CategoryTotal] {
        totalsByCategory(txns, from: period.start, to: period.end)
    }

    public static func totalsByCategory(_ txns: [TransactionRecord], from start: Date, to end: Date) -> [CategoryTotal] {
        var buckets: [UUID?: Decimal] = [:]
        for t in txns where t.type == .expense && t.date >= start && t.date < end {
            buckets[t.categoryID, default: 0] += t.amount
        }
        return buckets
            .map { CategoryTotal(categoryID: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
    }
}
