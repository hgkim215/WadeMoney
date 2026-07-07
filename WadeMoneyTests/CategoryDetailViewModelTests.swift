import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct CategoryDetailViewModelTests {
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

    @Test func summarizesTotalAndPercentForOneCategory() throws {
        let (repo, container) = try makeRepo()
        let food = try catID(repo, "식비"); let cafe = try catID(repo, "카페")
        try repo.addTransaction(amount: 300_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))
        try repo.addTransaction(amount: 100_000, type: .expense, categoryID: cafe, memo: nil, date: date(2026, 7, 6))

        let period = Period(kind: .month, start: date(2026, 7, 1), end: date(2026, 8, 1))
        let vm = CategoryDetailViewModel(repository: repo, categoryID: food, categoryName: "식비", period: period, calendar: utc)
        vm.load()

        #expect(vm.totalText == "300,000")
        #expect(vm.percentText == "75%")
        _ = container
    }

    @Test func listsOnlyThisCategorysTransactionsNewestFirst() throws {
        let (repo, container) = try makeRepo()
        let food = try catID(repo, "식비"); let cafe = try catID(repo, "카페")
        try repo.addTransaction(amount: 12_000, type: .expense, categoryID: food, memo: "점심 식사", date: date(2026, 7, 6))
        try repo.addTransaction(amount: 85_000, type: .expense, categoryID: food, memo: "장보기", date: date(2026, 7, 4))
        try repo.addTransaction(amount: 6_500, type: .expense, categoryID: cafe, memo: "카페", date: date(2026, 7, 1))

        let period = Period(kind: .month, start: date(2026, 7, 1), end: date(2026, 8, 1))
        let vm = CategoryDetailViewModel(repository: repo, categoryID: food, categoryName: "식비", period: period, calendar: utc)
        vm.load()

        #expect(vm.rows.count == 2)
        #expect(vm.rows[0].memo == "점심 식사")
        #expect(vm.rows[0].dateText == "7/6")
        #expect(vm.rows[0].amountText == "\u{2212}12,000")
        #expect(vm.rows[1].memo == "장보기")
        _ = container
    }

    @Test func fallsBackToCategoryNameWhenMemoIsEmpty() throws {
        let (repo, container) = try makeRepo()
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 12_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 6))

        let period = Period(kind: .month, start: date(2026, 7, 1), end: date(2026, 8, 1))
        let vm = CategoryDetailViewModel(repository: repo, categoryID: food, categoryName: "식비", period: period, calendar: utc)
        vm.load()

        #expect(vm.rows[0].memo == "식비")
        _ = container
    }

    @Test func flagsBudgetExcludedTransactions() throws {
        let (repo, container) = try makeRepo()
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 500_000, type: .expense, categoryID: food, memo: "용돈", date: date(2026, 7, 6), isExcludedFromBudget: true)

        let period = Period(kind: .month, start: date(2026, 7, 1), end: date(2026, 8, 1))
        let vm = CategoryDetailViewModel(repository: repo, categoryID: food, categoryName: "식비", period: period, calendar: utc)
        vm.load()

        #expect(vm.rows[0].showsBudgetExcludedLabel == true)
        _ = container
    }
}
