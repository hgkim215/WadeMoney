import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct LedgerHistoryTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int, _ hh: Int = 0) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d; comps.hour = hh
        return utc.date(from: comps)!
    }
    func repo() throws -> (LedgerRepository, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        return (LedgerRepository(context: container.mainContext), container)
    }
    func catID(_ r: LedgerRepository, _ n: String) throws -> UUID {
        try r.allCategories(includeArchived: false).first { $0.name == n }!.id
    }

    @Test func transactionsSortedDateDescending() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비")
        try r.addTransaction(amount: 1000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 10))
        try r.addTransaction(amount: 2000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 12))
        let all = try r.transactions(filter: .all)
        #expect(all.map(\.amount) == [2000, 1000])   // 최신 먼저
        _ = c
    }

    @Test func filterByCategoryAndIncome() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비"); let cafe = try catID(r, "카페")
        try r.addTransaction(amount: 1000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 10))
        try r.addTransaction(amount: 500, type: .expense, categoryID: cafe, memo: nil, date: date(2026, 7, 11))
        try r.addTransaction(amount: 9000, type: .income, categoryID: nil, memo: "환급", date: date(2026, 7, 12))
        #expect(try r.transactions(filter: .category(food)).map(\.amount) == [1000])
        #expect(try r.transactions(filter: .income).map(\.amount) == [9000])
        #expect(try r.transactions(filter: .all).count == 3)
        _ = c
    }

    @Test func updateTransactionChangesFieldsKeepsID() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비"); let cafe = try catID(r, "카페")
        try r.addTransaction(amount: 1000, type: .expense, categoryID: food, memo: "old", date: date(2026, 7, 10))
        let id = try r.transactions(filter: .all)[0].id
        try r.updateTransaction(id: id, amount: 3000, type: .expense, categoryID: cafe, memo: "new", date: date(2026, 7, 11))
        let rec = try #require(try r.transactionRecord(id: id))
        #expect(rec.id == id)
        #expect(rec.amount == 3000)
        #expect(rec.categoryID == cafe)
        #expect(rec.memo == "new")
        _ = c
    }

    @Test func totalIncomeSumsIncomeInPeriod() throws {
        let (r, c) = try repo()
        try r.addTransaction(amount: 9000, type: .income, categoryID: nil, memo: nil, date: date(2026, 7, 5))
        try r.addTransaction(amount: 1000, type: .income, categoryID: nil, memo: nil, date: date(2026, 8, 1))
        let calc = PeriodCalculator(calendar: utc, monthStartDay: 1)
        let july = calc.period(.month, containing: date(2026, 7, 1))
        #expect(try r.totalIncome(in: july) == 9000)
        _ = c
    }
}
