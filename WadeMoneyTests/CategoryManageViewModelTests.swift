import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct CategoryManageViewModelTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }
    func vm() throws -> (CategoryManageViewModel, LedgerRepository, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        let ctx = container.mainContext
        let repo = LedgerRepository(context: ctx)
        let vm = CategoryManageViewModel(categoryStore: CategoryStore(context: ctx), repository: repo,
                                         now: date(2026, 7, 15), calendar: utc)
        return (vm, repo, container)
    }

    @Test func loadsActiveWithUsage() throws {
        let (vm, repo, c) = try vm()
        let food = try repo.allCategories(includeArchived: false).first { $0.name == "식비" }!.id
        try repo.addTransaction(amount: 12000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 10))
        vm.load()
        #expect(vm.activeItems.count == 8)
        let foodItem = try #require(vm.activeItems.first { $0.name == "식비" })
        #expect(foodItem.usageText.contains("12,000"))
        let cafeItem = try #require(vm.activeItems.first { $0.name == "카페" })
        #expect(cafeItem.usageText == "이번 달 사용 없음")
        _ = c
    }

    @Test func addArchiveRestoreFlow() throws {
        let (vm, _, c) = try vm()
        vm.load()
        vm.add(name: "여행", iconName: "flight", colorHex: "#4DA0C4")
        #expect(vm.activeItems.contains { $0.name == "여행" })
        let travel = vm.activeItems.first { $0.name == "여행" }!.id
        vm.archive(id: travel)
        #expect(vm.activeItems.contains { $0.id == travel } == false)
        #expect(vm.archivedItems.contains { $0.id == travel })
        vm.restore(id: travel)
        #expect(vm.activeItems.contains { $0.id == travel })
        _ = c
    }
}
