import Foundation
import WadeMoneyCore

enum CSVExporter {
    static func csv(_ records: [TransactionRecord], categories: [CategoryRef], calendar: Calendar) -> String {
        let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        var lines = ["날짜,종류,카테고리,금액,메모"]
        let df = DateFormatter()
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        for r in records {
            let dateStr = df.string(from: r.date)
            let kind = r.type == .income ? "수입" : "지출"
            let catName = r.categoryID.flatMap { byID[$0] } ?? (r.type == .income ? "" : "기타")
            let amount = "\(NSDecimalNumber(decimal: r.amount).intValue)"
            let memo = escape(r.memo ?? "")
            lines.append("\(dateStr),\(kind),\(escape(catName)),\(amount),\(memo)")
        }
        return lines.joined(separator: "\n")
    }

    /// 콤마·따옴표·개행이 있으면 CSV 규칙대로 큰따옴표로 감싼다.
    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
