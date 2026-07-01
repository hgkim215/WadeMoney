import Foundation

enum Won {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.locale = Locale(identifier: "ko_KR")
        return f
    }()

    static func string(_ amount: Decimal) -> String {
        formatter.string(from: amount as NSDecimalNumber) ?? "0"
    }
}
