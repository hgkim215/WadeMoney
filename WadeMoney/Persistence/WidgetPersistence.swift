import Foundation
import SwiftData

/// 위젯은 앱이 쓴 App Group 공유 저장소를 읽기만 한다(CloudKit 동기화는 앱이 전담).
/// App Group이 프로비저닝되지 않았거나(미서명 시뮬레이터 등) 컨테이너 생성에 실패하면
/// 크래시 대신 nil을 돌려주고 각 위젯이 빈 데이터로 렌더링한다.
/// 컨테이너는 프로세스당 1회만 연다 — getTimeline마다 SQLite를 다시 열면
/// 메모리 예산이 빠듯한 위젯 확장에서 같은 비용이 반복된다.
enum WidgetPersistence {
    static let shared: ModelContainer? = {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppIDs.appGroup) != nil else {
            return nil
        }
        let config = ModelConfiguration(schema: PersistenceController.sharedSchema, groupContainer: .identifier(AppIDs.appGroup))
        return try? ModelContainer(for: PersistenceController.sharedSchema, configurations: [config])
    }()
}
