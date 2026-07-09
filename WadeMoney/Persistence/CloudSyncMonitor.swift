import CloudKit
import Foundation
import CoreData
import Observation
import os

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

    /// export(업로드) 이벤트의 현재 상태. 삭제 전 백업 확인, 설정 화면 상태 표시에 쓰인다.
    /// "진행 중"과 "실패로 종료됨"을 구분해야 사용자에게 정확한 안내를 줄 수 있다 —
    /// 둘 다 하나의 Bool로 뭉뚱그리면 실패해도 영원히 "업로드 중"으로 보인다.
    enum ExportStatus: Equatable {
        case idle
        case uploading
        case failed(reason: String)
    }

    private(set) var state: State
    private(set) var exportStatus: ExportStatus = .idle
    /// Logger는 스레드 세이프해서 actor 격리가 필요 없다 — 알림 옵저버 클로저(메인 액터 밖)에서도 그대로 쓴다.
    private nonisolated static let logger = Logger(subsystem: "com.kimhyeongi.WadeMoney", category: "CloudSync")
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

    static func nextExportStatus(
        current: ExportStatus,
        eventType: NSPersistentCloudKitContainer.EventType,
        isFinished: Bool,
        succeeded: Bool,
        errorDescription: String?
    ) -> ExportStatus {
        guard eventType == .export else { return current }
        guard isFinished else { return .uploading }
        return succeeded ? .idle : .failed(reason: errorDescription ?? "알 수 없는 오류")
    }

    /// `unavailable`일 때만 의미 있는 재판정 — 컨테이너 자체가 CloudKit 없이 만들어졌으면
    /// (cloudKitEnabled == false) 세션 중에는 손쓸 방법이 없다. 그 외의 경우 로그인 여부가
    /// 바뀌었으면 importing/normal로 전환한다.
    static func recheckedState(current: State, cloudKitEnabled: Bool, isSignedIntoiCloud: Bool, hasExistingData: Bool) -> State {
        guard current == .unavailable, cloudKitEnabled, isSignedIntoiCloud else { return current }
        return hasExistingData ? .normal : .importing
    }

    /// partialFailure(코드 2)의 최상위 메시지는 "Partial failure" 정도로 뭉뚱그려져 있어 원인 파악이 안 된다 —
    /// 레코드별 세부 에러(CKError.partialErrorsByItemID)를 풀어서 실제 실패 사유를 보여준다.
    /// 인스턴스 상태를 건드리지 않는 순수 함수라 알림 옵저버 클로저(메인 액터 밖)에서도 그대로 부른다.
    nonisolated static func describeExportError(_ error: Error?) -> String? {
        guard let error else { return nil }
        guard let ckError = error as? CKError else { return error.localizedDescription }
        guard ckError.code == .partialFailure,
              let partialErrors = ckError.partialErrorsByItemID, !partialErrors.isEmpty
        else {
            return ckError.localizedDescription
        }
        let reasons = partialErrors.values.map { ($0 as NSError).localizedDescription }
        guard let primary = reasons.first else { return ckError.localizedDescription }
        let extraCount = reasons.count - 1
        return extraCount > 0 ? "\(primary) (외 \(extraCount)건)" : primary
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
            let errorDescription = CloudSyncMonitor.describeExportError(event.error)
            if let errorDescription {
                // Console.app에서 "CloudSync" 카테고리로 필터링하면 실제 CKError 사유를 볼 수 있다 —
                // 실패한 export가 UI에 "업로드 중"으로만 뭉뚱그려 보이던 문제의 진단 통로.
                CloudSyncMonitor.logger.error("CloudKit \(type == .export ? "export" : "import") failed: \(errorDescription, privacy: .public)")
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.state = CloudSyncMonitor.nextState(current: self.state, eventType: type, isFinished: isFinished, succeeded: succeeded)
                self.exportStatus = CloudSyncMonitor.nextExportStatus(
                    current: self.exportStatus, eventType: type, isFinished: isFinished,
                    succeeded: succeeded, errorDescription: errorDescription)
            }
        }
    }
}
