import Foundation

public struct DonutSlice: Equatable, Sendable {
    public let categoryID: UUID?   // nil = 병합된 "기타" 슬라이스
    public let total: Decimal
    public let fraction: Double
    public let isOther: Bool

    public init(categoryID: UUID?, total: Decimal, fraction: Double, isOther: Bool) {
        self.categoryID = categoryID
        self.total = total
        self.fraction = fraction
        self.isOther = isOther
    }
}

public enum Donut {
    /// 상위 (maxSlices-1)개 + 나머지 병합. 0 이하 카테고리 제외.
    public static func slices(_ totals: [CategoryTotal], maxSlices: Int = 6) -> [DonutSlice] {
        let positive = totals.filter { $0.total > 0 }.sorted { $0.total > $1.total }
        let grand = positive.reduce(Decimal(0)) { $0 + $1.total }
        guard grand > 0 else { return [] }

        func fraction(_ value: Decimal) -> Double { (value / grand).doubleValue }

        if positive.count <= maxSlices {
            return positive.map {
                DonutSlice(categoryID: $0.categoryID, total: $0.total, fraction: fraction($0.total), isOther: false)
            }
        }

        let head = positive.prefix(maxSlices - 1)
        let tail = positive.dropFirst(maxSlices - 1)
        var result = head.map {
            DonutSlice(categoryID: $0.categoryID, total: $0.total, fraction: fraction($0.total), isOther: false)
        }
        let otherTotal = tail.reduce(Decimal(0)) { $0 + $1.total }
        result.append(DonutSlice(categoryID: nil, total: otherTotal, fraction: fraction(otherTotal), isOther: true))
        return result
    }
}
