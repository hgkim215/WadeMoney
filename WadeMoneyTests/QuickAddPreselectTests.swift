import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct QuickAddPreselectTests {
    func repo() throws -> (LedgerRepository, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        return (LedgerRepository(context: container.mainContext), container)
    }
    func catID(_ r: LedgerRepository, _ n: String) throws -> UUID {
        try r.allCategories(includeArchived: false).first { $0.name == n }!.id
    }

    @Test func preselectsCategoryWhenAddingNew() throws {
        let (r, c) = try repo()
        let cafe = try catID(r, "카페")
        let vm = QuickAddViewModel(repository: r, preselectedCategoryID: cafe)
        #expect(vm.selectedCategoryID == cafe)
        #expect(!vm.isEditing)
        _ = c
    }

    @Test func noPreselectionMeansNoCategorySelected() throws {
        let (r, c) = try repo()
        let vm = QuickAddViewModel(repository: r)
        #expect(vm.selectedCategoryID == nil)
        _ = c
    }
}
