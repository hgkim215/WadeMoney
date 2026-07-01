import Foundation
import SwiftData
import Testing
@testable import WadeMoney

@MainActor
struct ModelPersistenceTests {
    /// 인메모리·비-CloudKit 컨테이너 (시뮬레이터에서 CloudKit 없이 동작).
    func makeContainer() throws -> ModelContainer {
        let schema = Schema([CategoryModel.self, TransactionModel.self, MonthlyBudgetModel.self, AppSettingsModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test func insertsAndFetchesTransactionWithCategory() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let cafe = CategoryModel(name: "카페", iconName: "local_cafe", colorHex: "#C4924E", sortOrder: 1)
        ctx.insert(cafe)
        let tx = TransactionModel(amount: 4800, type: .expense, category: cafe,
                                  memo: "아메리카노", date: Date(timeIntervalSince1970: 1_000))
        ctx.insert(tx)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<TransactionModel>())
        #expect(fetched.count == 1)
        #expect(fetched[0].amount == 4800)
        #expect(fetched[0].type == .expense)
        #expect(fetched[0].category?.name == "카페")
    }

    @Test func typeRawMapsToTransactionKind() throws {
        let tx = TransactionModel(amount: 100, type: .income, category: nil,
                                  memo: nil, date: Date(timeIntervalSince1970: 0))
        #expect(tx.typeRaw == "income")
        tx.type = .expense
        #expect(tx.typeRaw == "expense")
        // 알 수 없는 원시값은 지출로 폴백
        tx.typeRaw = "garbage"
        #expect(tx.type == .expense)
    }
}
