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
        // CloudKit 병합으로 생긴 중복 카테고리를 매 실행 시 결정적으로 합친다(멱등).
        try? CategorySeeder.reconcileDuplicateCategories(resolved.mainContext)
        try? _ = SettingsStore(context: resolved.mainContext).settingsModel()

        let existingData = ((try? resolved.mainContext.fetchCount(FetchDescriptor<TransactionModel>())) ?? 0) > 0
        hasExistingData = existingData
        let monitor = CloudSyncMonitor(
            cloudKitEnabled: cloudKitEnabled,
            isSignedIntoiCloud: FileManager.default.ubiquityIdentityToken != nil,
            hasExistingData: existingData
        )
        syncMonitor = monitor

        // 재설치 직후(.importing)에는 시드를 미룬다 — iCloud에 이미 있는 카테고리·시드 플래그가
        // 내려오기 전에 시드하면 재설치할 때마다 새 UUID 8개가 클라우드에 누적된다.
        // import가 완료되면(성공/실패 무관) 그때 시드 여부를 판단하고 중복을 병합한다.
        let context = resolved.mainContext
        monitor.onImportCompleted = {
            try? CategorySeeder.seedIfNeeded(context)
            try? CategorySeeder.reconcileDuplicateCategories(context)
        }
        if monitor.state == .importing {
            // import 이벤트가 영영 안 오는 기기(백오프·계정 문제)에서도 기본 카테고리 없이
            // 방치되지 않도록 안전망 — seedIfNeeded는 멱등이라 중복 호출해도 안전하다.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(15))
                try? CategorySeeder.seedIfNeeded(context)
                try? CategorySeeder.reconcileDuplicateCategories(context)
            }
        } else {
            try? CategorySeeder.seedIfNeeded(context)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(hasExistingData: hasExistingData)
        }
        .modelContainer(container)
        .environment(syncMonitor)
    }
}
