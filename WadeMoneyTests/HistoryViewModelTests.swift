import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct HistoryViewModelTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int, _ hh: Int = 12) -> Date {
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

    @Test func groupsByDayWithTodayTag() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비")
        try r.addTransaction(amount: 9000, type: .expense, categoryID: food, memo: "점심", date: date(2026, 7, 15, 12))
        try r.addTransaction(amount: 3000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 14, 9))
        let vm = HistoryViewModel(repository: r, now: date(2026, 7, 15, 20), calendar: utc)
        vm.load()
        #expect(vm.groups.count == 2)
        #expect(vm.groups[0].tag == "오늘")       // 최신 그룹 = 오늘
        #expect(vm.groups[1].tag == "어제")
        #expect(vm.groups[0].sumText.contains("9,000"))
        #expect(vm.groups[0].rows.first?.isIncome == false)
        _ = c
    }

    @Test func incomeFilterShowsOnlyIncome() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비")
        try r.addTransaction(amount: 9000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 15))
        try r.addTransaction(amount: 45000, type: .income, categoryID: nil, memo: "환급", date: date(2026, 7, 15))
        let vm = HistoryViewModel(repository: r, now: date(2026, 7, 15, 20), calendar: utc)
        vm.filter = .income
        vm.load()
        let allRows = vm.groups.flatMap(\.rows)
        #expect(allRows.count == 1)
        #expect(allRows[0].isIncome == true)
        #expect(allRows[0].amountText.hasPrefix("+"))
        _ = c
    }

    @Test func emptyWhenNoMatches() throws {
        let (r, c) = try repo()
        let vm = HistoryViewModel(repository: r, now: date(2026, 7, 15), calendar: utc)
        vm.filter = .income
        vm.load()
        #expect(vm.isEmpty)
        _ = c
    }

    @Test func searchFiltersByMemoCategoryAndAmount() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비")
        let cafe = try catID(r, "카페")
        try r.addTransaction(amount: 9000, type: .expense, categoryID: food, memo: "점심 김밥", date: date(2026, 7, 15, 12))
        try r.addTransaction(amount: 4800, type: .expense, categoryID: cafe, memo: "아메리카노", date: date(2026, 7, 15, 13))

        let vm = HistoryViewModel(repository: r, now: date(2026, 7, 15, 20), calendar: utc)
        vm.searchQuery = "김밥"
        vm.load()
        #expect(vm.groups.flatMap(\.rows).map(\.name) == ["점심 김밥"])

        vm.searchQuery = "카페"
        vm.load()
        #expect(vm.groups.flatMap(\.rows).map(\.name) == ["아메리카노"])

        vm.searchQuery = "4,800"
        vm.load()
        #expect(vm.groups.flatMap(\.rows).map(\.amountText) == ["−4,800"])
        _ = c
    }

    @Test func mixedExpenseAndIncomeDayShowsExpenseSumOnly() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비")
        try r.addTransaction(amount: 9000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 15, 12))
        try r.addTransaction(amount: 45000, type: .income, categoryID: nil, memo: "환급", date: date(2026, 7, 15, 14))
        let vm = HistoryViewModel(repository: r, now: date(2026, 7, 15, 20), calendar: utc)
        vm.load()
        // 지출+수입이 섞인 날은 지출 합계만 표시(수입은 개별 행에서만 확인). 의도된 동작.
        #expect(vm.groups[0].sumText == "−9,000")
        #expect(vm.groups[0].sumIsIncome == false)
        _ = c
    }
}
