import SwiftUI
import SwiftData

@main
struct WadeMoneyApp: App {
    let container: ModelContainer
    let syncMonitor: CloudSyncMonitor
    let hasExistingData: Bool

    init() {
        // 테스트 호스트로 실행 중이면 App Group/CloudKit 엔타이틀먼트가 없어
        // makeAppContainer()가 복구 불가능한 fatal error를 낼 수 있으므로 우회한다.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            container = try! PersistenceController.makeInMemoryContainer()
            syncMonitor = CloudSyncMonitor(cloudKitEnabled: false, isSignedIntoiCloud: false, hasExistingData: false)
            hasExistingData = false
            return
        }
        let resolved: ModelContainer
        let cloudKitEnabled: Bool
        do {
            let result = try PersistenceController.makeAppContainer()
            resolved = result.container
            cloudKitEnabled = result.cloudKitEnabled
        } catch {
            // CloudKit 초기화 실패 시 온디스크 로컬 저장소로 폴백(데이터가 콜드런치마다 사라지지 않도록).
            do {
                resolved = try PersistenceController.makeLocalContainer()
            } catch {
                // 로컬 저장소마저 실패하면 최후 수단으로 인메모리 폴백(앱은 뜬다).
                resolved = try! PersistenceController.makeInMemoryContainer()
            }
            cloudKitEnabled = false
        }
        container = resolved
        try? CategorySeeder.seedIfNeeded(resolved.mainContext)
        // CloudKit 병합으로 생긴 중복 카테고리를 매 실행 시 결정적으로 합친다(멱등).
        try? CategorySeeder.reconcileDuplicateCategories(resolved.mainContext)
        try? _ = SettingsStore(context: resolved.mainContext).settingsModel()

        let existingData = ((try? resolved.mainContext.fetchCount(FetchDescriptor<TransactionModel>())) ?? 0) > 0
        hasExistingData = existingData
        syncMonitor = CloudSyncMonitor(
            cloudKitEnabled: cloudKitEnabled,
            isSignedIntoiCloud: FileManager.default.ubiquityIdentityToken != nil,
            hasExistingData: existingData
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(hasExistingData: hasExistingData)
        }
        .modelContainer(container)
        .environment(syncMonitor)
    }
}
