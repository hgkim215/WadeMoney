import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct CategoryBreakdownViewModelTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }
    func makeRepo() throws -> (LedgerRepository, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        return (LedgerRepository(context: container.mainContext), container)
    }
    func catID(_ repo: LedgerRepository, _ name: String) throws -> UUID {
        try repo.allCategories(includeArchived: false).first { $0.name == name }!.id
    }

    @Test func ranksAllCategoriesByAmountDescendingWithPercent() throws {
        let (repo, container) = try makeRepo()
        let food = try catID(repo, "식비"); let cafe = try catID(repo, "카페")
        try repo.addTransaction(amount: 300_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))
        try repo.addTransaction(amount: 100_000, type: .expense, categoryID: cafe, memo: nil, date: date(2026, 7, 6))

        let period = Period(kind: .month, start: date(2026, 7, 1), end: date(2026, 8, 1))
        let vm = CategoryBreakdownViewModel(repository: repo, period: period)
        vm.load()

        #expect(vm.rows.count == 2)
        #expect(vm.rows[0].name == "식비")
        #expect(vm.rows[0].amountText == "300,000")
        #expect(vm.rows[0].percentText == "75%")
        #expect(vm.rows[1].name == "카페")
        #expect(vm.rows[1].percentText == "25%")
        _ = container
    }

    @Test func excludesTransactionsOutsideThePeriod() throws {
        let (repo, container) = try makeRepo()
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 50_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 6, 30))
        try repo.addTransaction(amount: 70_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))

        let period = Period(kind: .month, start: date(2026, 7, 1), end: date(2026, 8, 1))
        let vm = CategoryBreakdownViewModel(repository: repo, period: period)
        vm.load()

        #expect(vm.rows.count == 1)
        #expect(vm.rows[0].amountText == "70,000")
        _ = container
    }

    @Test func emptyPeriodProducesNoRows() throws {
        let (repo, container) = try makeRepo()
        let period = Period(kind: .month, start: date(2026, 7, 1), end: date(2026, 8, 1))
        let vm = CategoryBreakdownViewModel(repository: repo, period: period)
        vm.load()
        #expect(vm.rows.isEmpty)
        _ = container
    }
}
