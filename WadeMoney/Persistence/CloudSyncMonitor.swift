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
    /// deinit은 Swift 6에서 항상 nonisolated로 실행되므로, MainActor 격리 없이 접근 가능해야 한다.
    /// NotificationCenter.removeObserver(_:)는 어느 스레드에서 호출해도 안전하다.
    /// (plain `nonisolated`는 @Observable 매크로의 @ObservationTracked 확장과 충돌해 빌드가 깨진다 — unsafe 필요.)
    @ObservationIgnored
    private nonisolated(unsafe) var observer: NSObjectProtocol?
    private let cloudKitEnabled: Bool
    private let hasExistingDataAtLaunch: Bool

    init(cloudKitEnabled: Bool, isSignedIntoiCloud: Bool, hasExistingData: Bool) {
        self.cloudKitEnabled = cloudKitEnabled
        self.hasExistingDataAtLaunch = hasExistingData
        state = CloudSyncMonitor.initialState(
            cloudKitEnabled: cloudKitEnabled,
            isSignedIntoiCloud: isSignedIntoiCloud,
            hasExistingData: hasExistingData
        )
        if cloudKitEnabled {
            startObserving()
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
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

    /// `unavailable`일 때만 의미 있는 재판정 — 컨테이너 자체가 CloudKit 없이 만들어졌으면
    /// (cloudKitEnabled == false) 세션 중에는 손쓸 방법이 없다. 그 외의 경우 로그인 여부가
    /// 바뀌었으면 importing/normal로 전환한다.
    static func recheckedState(current: State, cloudKitEnabled: Bool, isSignedIntoiCloud: Bool, hasExistingData: Bool) -> State {
        guard current == .unavailable, cloudKitEnabled, isSignedIntoiCloud else { return current }
        return hasExistingData ? .normal : .importing
    }

    /// iCloud 로그인 상태를 지금 다시 확인한다. `ModelContainer`는 건드리지 않는다 —
    /// 세션 중에는 재생성할 수 없기 때문에, 계정 로그인 여부만 다시 읽어 상태를 갱신한다.
    func recheckSignIn() {
        state = CloudSyncMonitor.recheckedState(
            current: state,
            cloudKitEnabled: cloudKitEnabled,
            isSignedIntoiCloud: FileManager.default.ubiquityIdentityToken != nil,
            hasExistingData: hasExistingDataAtLaunch
        )
    }

    private func startObserving() {
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
            let type = event.type
            let isFinished = event.endDate != nil
            let succeeded = event.succeeded
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.state = CloudSyncMonitor.nextState(current: self.state, eventType: type, isFinished: isFinished, succeeded: succeeded)
                self.pendingExport = CloudSyncMonitor.nextPendingExport(current: self.pendingExport, eventType: type, isFinished: isFinished, succeeded: succeeded)
            }
        }
    }
}
