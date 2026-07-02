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
        try vm.save()

        let updated = try #require(try r.transactionRecord(id: rec.id))
        #expect(updated.amount == 7000)
        #expect(updated.categoryID == cafe)
        #expect(try r.transactions(filter: .all).count == 1)   // 새로 추가되지 않음
        _ = c
    }

    @Test func editingPreservesOriginalDateByDefault() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비")
        let originalDate = date()
        try r.addTransaction(amount: 5000, type: .expense, categoryID: food, memo: nil, date: originalDate)
        let rec = try r.transactions(filter: .all)[0]

        let vm = QuickAddViewModel(repository: r, editing: rec)
        #expect(vm.date == originalDate)   // 편집 시작 시 날짜가 원본으로 프리필됨
        vm.amountDigits = "6000"
        // 날짜를 건드리지 않고 금액만 고치면 원래 날짜가 유지되어야 한다.
        try vm.save()

        let updated = try #require(try r.transactionRecord(id: rec.id))
        #expect(updated.amount == 6000)
        #expect(updated.date == originalDate)
        _ = c
    }

    @Test func editingAllowsChangingTransactionDate() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비")
        let originalDate = date()
        try r.addTransaction(amount: 5000, type: .expense, categoryID: food, memo: nil, date: originalDate)
        let rec = try r.transactions(filter: .all)[0]

        let vm = QuickAddViewModel(repository: r, editing: rec)
        let newDate = originalDate.addingTimeInterval(86_400)
        vm.date = newDate
        try vm.save()

        let updated = try #require(try r.transactionRecord(id: rec.id))
        #expect(updated.date == newDate)
        _ = c
    }
}
