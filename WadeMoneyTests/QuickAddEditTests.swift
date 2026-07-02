import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct QuickAddEditTests {
    func repo() throws -> (LedgerRepository, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        return (LedgerRepository(context: container.mainContext), container)
    }
    func catID(_ r: LedgerRepository, _ n: String) throws -> UUID {
        try r.allCategories(includeArchived: false).first { $0.name == n }!.id
    }
    func date() -> Date { Date(timeIntervalSince1970: 1_000_000) }

    @Test func editingPrefillsAndUpdates() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비"); let cafe = try catID(r, "카페")
        try r.addTransaction(amount: 5000, type: .expense, categoryID: food, memo: "old", date: date())
        let rec = try r.transactions(filter: .all)[0]

        let vm = QuickAddViewModel(repository: r, editing: rec)
        #expect(vm.isEditing)
        #expect(vm.amountDecimal == 5000)
        #expect(vm.selectedCategoryID == food)
        #expect(vm.memo == "old")

        vm.selectedCategoryID = cafe
        vm.amountDigits = "7000"
        try vm.save(date: date())

        let updated = try #require(try r.transactionRecord(id: rec.id))
        #expect(updated.amount == 7000)
        #expect(updated.categoryID == cafe)
        #expect(try r.transactions(filter: .all).count == 1)   // 새로 추가되지 않음
        _ = c
    }

    @Test func deleteRemovesTransaction() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비")
        try r.addTransaction(amount: 5000, type: .expense, categoryID: food, memo: nil, date: date())
        let rec = try r.transactions(filter: .all)[0]
        let vm = QuickAddViewModel(repository: r, editing: rec)
        try vm.delete()
        #expect(try r.transactions(filter: .all).isEmpty)
        _ = c
    }
}
