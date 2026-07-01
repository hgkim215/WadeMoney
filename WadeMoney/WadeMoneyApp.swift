import SwiftUI
import SwiftData

@main
struct WadeMoneyApp: App {
    let container: ModelContainer

    init() {
        // 테스트 호스트로 실행 중이면 App Group/CloudKit 엔타이틀먼트가 없어
        // makeAppContainer()가 복구 불가능한 fatal error를 낼 수 있으므로 우회한다.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            container = try! PersistenceController.makeInMemoryContainer()
            return
        }
        let resolved: ModelContainer
        do {
            resolved = try PersistenceController.makeAppContainer()
        } catch {
            // CloudKit 초기화 실패 시 온디스크 로컬 저장소로 폴백(데이터가 콜드런치마다 사라지지 않도록).
            do {
                resolved = try PersistenceController.makeLocalContainer()
            } catch {
                // 로컬 저장소마저 실패하면 최후 수단으로 인메모리 폴백(앱은 뜬다).
                resolved = try! PersistenceController.makeInMemoryContainer()
            }
        }
        container = resolved
        try? CategorySeeder.seedIfNeeded(resolved.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
