import Foundation
import SwiftData
import Testing
@testable import WadeMoney

@MainActor
struct PersistenceControllerTests {
    @Test func inMemoryContainerInsertsAndFetches() throws {
        let container = try PersistenceController.makeInMemoryContainer()
        let ctx = container.mainContext
        ctx.insert(AppSettingsModel(monthStartDay: 1))
        try ctx.save()
        let count = try ctx.fetchCount(FetchDescriptor<AppSettingsModel>())
        #expect(count == 1)
    }

    @Test func schemaCoversAllModels() {
        // 스키마에 4개 엔티티가 모두 등록됐는지 확인.
        let names = Set(PersistenceController.sharedSchema.entities.map(\.name))
        #expect(names.isSuperset(of: ["CategoryModel", "TransactionModel", "MonthlyBudgetModel", "AppSettingsModel"]))
    }
}
