import Foundation

extension Decimal {
    public var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
