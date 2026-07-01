import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct QuickAddViewModelTests {
    func makeVM() throws -> (QuickAddViewModel, LedgerRepository, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        let repo = LedgerRepository(context: container.mainContext)
        return (QuickAddViewModel(repository: repo), repo, container)
    }
    func date() -> Date { Date(timeIntervalSince1970: 1_000_000) }

    @Test func keypadBuildsAmount() throws {
        let (vm, _, container) = try makeVM()
        vm.tapKey("4"); vm.tapKey("8"); vm.tapKey("00")
        #expect(vm.amountDecimal == 4800)
        vm.backspace()
        #expect(vm.amountDecimal == 480)
        _ = container
    }

    @Test func expenseRequiresCategory() throws {
        let (vm, _, container) = try makeVM()
        vm.tapKey("5"); vm.tapKey("0"); vm.tapKey("00")
        #expect(vm.canSave == false)            // 카테고리 미선택
        vm.selectedCategoryID = vm.categories.first?.id
        #expect(vm.canSave == true)
        _ = container
    }

    @Test func incomeNeedsNoCategoryAndSaves() throws {
        let (vm, repo, container) = try makeVM()
        vm.type = .income
        vm.tapKey("4"); vm.tapKey("5"); vm.tapKey("000")
        #expect(vm.selectedCategoryID == nil)
        #expect(vm.canSave == true)
        try vm.save(date: date())
        let all = try repo.allTransactions()
        #expect(all.count == 1)
        #expect(all[0].type == .income)
        _ = container
    }
}
