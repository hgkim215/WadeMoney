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
        do {
            container = try PersistenceController.makeAppContainer()
        } catch {
            // 최초 마이그레이션/프로비저닝 실패 시 로컬 인메모리로 폴백(앱은 뜬다).
            container = try! PersistenceController.makeInMemoryContainer()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
