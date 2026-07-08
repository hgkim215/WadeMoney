import Foundation
import CoreData
import Observation

/// 대시보드 배너와 설정 화면이 구독하는 단일 CloudKit 동기화 상태 소스.
/// 앱 세션 내내 하나의 인스턴스를 `.environment(_:)`로 주입해 공유한다.
@MainActor
@Observable
final class CloudSyncMonitor {
    enum State: Equatable {
        case normal
        case importing
        case unavailable
    }

    private(set) var state: State
    /// 로컬 변경사항이 아직 iCloud로 업로드되지 않았으면 true (삭제 전 백업 확인에 사용).
    private(set) var pendingExport: Bool = false

    init(cloudKitEnabled: Bool, isSignedIntoiCloud: Bool, hasExistingData: Bool) {
        state = CloudSyncMonitor.initialState(
            cloudKitEnabled: cloudKitEnabled,
            isSignedIntoiCloud: isSignedIntoiCloud,
            hasExistingData: hasExistingData
        )
    }

    static func initialState(cloudKitEnabled: Bool, isSignedIntoiCloud: Bool, hasExistingData: Bool) -> State {
        guard cloudKitEnabled, isSignedIntoiCloud else { return .unavailable }
        return hasExistingData ? .normal : .importing
    }

    /// NSPersistentCloudKitContainer.Event는 공개 이니셜라이저가 없어 테스트에서 직접 만들 수 없다.
    /// 그래서 이벤트에서 뽑아낸 원시 값(enum/Bool)만 받는 순수 함수로 분리해 유닛 테스트 가능하게 한다.
    static func nextState(
        current: State,
        eventType: NSPersistentCloudKitContainer.EventType,
        isFinished: Bool,
        succeeded: Bool
    ) -> State {
        guard eventType == .import, isFinished else { return current }
        return succeeded ? .normal : .unavailable
    }

    static func nextPendingExport(
        current: Bool,
        eventType: NSPersistentCloudKitContainer.EventType,
        isFinished: Bool,
        succeeded: Bool
    ) -> Bool {
        guard eventType == .export else { return current }
        return isFinished ? !succeeded : true
    }
}
