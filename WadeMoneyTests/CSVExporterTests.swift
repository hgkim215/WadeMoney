import Foundation
import Testing
import WadeMoneyCore
@testable import WadeMoney

struct CSVExporterTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }

    @Test func csvHasHeaderAndRows() {
        let food = CategoryRef(id: UUID(), name: "식비", iconName: "restaurant", colorHex: "#E28A4E", sortOrder: 0)
        let recs = [
            TransactionRecord(amount: 9000, type: .expense, categoryID: food.id, memo: "점심", date: date(2026, 7, 15)),
            TransactionRecord(amount: 45000, type: .income, categoryID: nil, memo: nil, date: date(2026, 7, 10)),
        ]
        let csv = CSVExporter.csv(recs, categories: [food], calendar: utc)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.first == "날짜,종류,카테고리,금액,메모")
        #expect(lines.contains { $0.contains("2026-07-15") && $0.contains("지출") && $0.contains("식비") && $0.contains("9000") && $0.contains("점심") })
        #expect(lines.contains { $0.contains("2026-07-10") && $0.contains("수입") && $0.contains("45000") })
    }

    @Test func neutralizesSpreadsheetFormulaInjectionInMemo() {
        let food = CategoryRef(id: UUID(), name: "식비", iconName: "restaurant", colorHex: "#E28A4E", sortOrder: 0)
        let recs = [
            TransactionRecord(amount: 1000, type: .expense, categoryID: food.id,
                              memo: "=HYPERLINK(\"http://evil\",\"x\")", date: date(2026, 7, 15)),
            TransactionRecord(amount: 2000, type: .expense, categoryID: food.id, memo: "@SUM(A1)", date: date(2026, 7, 15)),
            TransactionRecord(amount: 3000, type: .expense, categoryID: food.id, memo: "+1+1", date: date(2026, 7, 15)),
        ]
        let csv = CSVExporter.csv(recs, categories: [food], calendar: utc)
        // 수식 선행 문자로 시작하는 셀은 '가 앞에 붙어 스프레드시트가 수식으로 실행하지 않는다.
        #expect(csv.contains("'=HYPERLINK"))
        #expect(csv.contains("'@SUM(A1)"))
        #expect(csv.contains("'+1+1"))
        #expect(!csv.contains(",=HYPERLINK"))
    }
}
