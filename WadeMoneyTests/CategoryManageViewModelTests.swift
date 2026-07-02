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

    @Test func unusedCategoryCanBeDeletedImmediately() throws {
        let (vm, _, c) = try vm()
        vm.load()
        vm.add(name: "실수", iconName: "flight", colorHex: "#4DA0C4")
        let mistake = try #require(vm.activeItems.first { $0.name == "실수" })
        #expect(mistake.canDelete)   // 거래가 하나도 없음

        vm.delete(id: mistake.id)
        #expect(!vm.activeItems.contains { $0.id == mistake.id })
        #expect(!vm.archivedItems.contains { $0.id == mistake.id })   // 보관이 아니라 완전히 사라짐
        _ = c
    }

    @Test func categoryWithPastTransactionsCannotBeDeletedEvenIfUnusedThisMonth() throws {
        let (vm, repo, c) = try vm()
        let food = try repo.allCategories(includeArchived: false).first { $0.name == "식비" }!.id
        // 이번 달(7월)이 아니라 지난달에만 사용 — usageText는 "사용 없음"이지만 과거 이력은 존재.
        try repo.addTransaction(amount: 9000, type: .expense, categoryID: food, memo: nil, date: date(2026, 6, 5))
        vm.load()

        let foodItem = try #require(vm.activeItems.first { $0.name == "식비" })
        #expect(foodItem.usageText == "이번 달 사용 없음")
        #expect(!foodItem.canDelete)   // 과거 통계 무결성 보존을 위해 삭제 불가 — 보관만 가능

        vm.delete(id: foodItem.id)
        #expect(vm.activeItems.contains { $0.id == foodItem.id })   // 삭제 시도가 조용히 무시됨
        _ = c
    }
}
