import Foundation
import SwiftData

enum PersistenceController {
    static let sharedSchema = Schema([
        CategoryModel.self,
        TransactionModel.self,
        MonthlyBudgetModel.self,
        AppSettingsModel.self,
    ])

    /// 프로덕션: App Group 공유 저장소 + CloudKit 개인 DB 동기화.
    /// (실제 동기화는 유료 Apple Developer 계정 + 프로비저닝된 iCloud 컨테이너 + 실기기 필요.)
    static func makeAppContainer() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: sharedSchema,
            groupContainer: .identifier(AppIDs.appGroup),
            cloudKitDatabase: .private(AppIDs.iCloudContainer)
        )
        return try ModelContainer(for: sharedSchema, configurations: [config])
    }

    /// 테스트/프리뷰: 인메모리, CloudKit 없음.
    static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: sharedSchema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: sharedSchema, configurations: [config])
    }
}
