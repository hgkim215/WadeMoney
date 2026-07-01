import Foundation
import SwiftData

enum PersistenceController {
    static let sharedSchema = Schema([
        CategoryModel.self,
        TransactionModel.self,
        MonthlyBudgetModel.self,
        AppSettingsModel.self,
    ])

    /// App Group 컨테이너가 실제로 프로비저닝돼 있는지(엔타이틀먼트 유효 여부).
    /// 미서명 시뮬레이터 등에서는 nil → App Group/CloudKit 경로를 시도하면
    /// SwiftData가 잡을 수 없는 fatalError를 낸다. 그래서 먼저 확인한다.
    private static var isAppGroupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppIDs.appGroup) != nil
    }

    /// 프로덕션: App Group 공유 저장소 + CloudKit 개인 DB 동기화.
    /// App Group이 프로비저닝되지 않은 환경(미서명 시뮬레이터 등)에서는
    /// 공유·CloudKit 없이 로컬 온디스크로 기동해 앱이 크래시 없이 뜨게 한다.
    /// (실제 동기화는 유료 Apple Developer 계정 + 프로비저닝된 iCloud 컨테이너 + 실기기 필요.)
    static func makeAppContainer() throws -> ModelContainer {
        guard isAppGroupAvailable else {
            return try makeLocalContainer()
        }
        let config = ModelConfiguration(
            schema: sharedSchema,
            groupContainer: .identifier(AppIDs.appGroup),
            cloudKitDatabase: .private(AppIDs.iCloudContainer)
        )
        return try ModelContainer(for: sharedSchema, configurations: [config])
    }

    /// 로컬 온디스크 폴백: 그룹·CloudKit 없는 플레인 저장소.
    /// (CloudKit 초기화 실패 시에도, 또는 App Group 미프로비저닝 환경에서도
    /// 데이터가 콜드런치마다 사라지지 않도록.)
    static func makeLocalContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: sharedSchema)
        return try ModelContainer(for: sharedSchema, configurations: [config])
    }

    /// 테스트/프리뷰: 인메모리, CloudKit 없음.
    static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: sharedSchema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: sharedSchema, configurations: [config])
    }
}
