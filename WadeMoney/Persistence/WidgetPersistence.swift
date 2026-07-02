import Foundation
import SwiftData

/// 위젯은 앱이 쓴 App Group 공유 저장소를 읽기만 한다(CloudKit 동기화는 앱이 전담).
/// App Group이 프로비저닝되지 않은 환경(미서명 시뮬레이터 등)에서는 크래시 대신
/// 빈 인메모리 컨테이너로 폴백한다 — PersistenceController의 크래시 방지 패턴과 동일 원칙.
enum WidgetPersistence {
    private static var isAppGroupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppIDs.appGroup) != nil
    }

    static func makeContainer() -> ModelContainer {
        guard isAppGroupAvailable else { return emptyFallback() }
        do {
            let config = ModelConfiguration(schema: PersistenceController.sharedSchema, groupContainer: .identifier(AppIDs.appGroup))
            return try ModelContainer(for: PersistenceController.sharedSchema, configurations: [config])
        } catch {
            return emptyFallback()
        }
    }

    private static func emptyFallback() -> ModelContainer {
        let config = ModelConfiguration(schema: PersistenceController.sharedSchema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: PersistenceController.sharedSchema, configurations: [config])
    }
}
