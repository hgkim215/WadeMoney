import CoreData
import Testing
@testable import WadeMoney

@MainActor
struct CloudSyncMonitorTests {
    @Test func unavailableWhenCloudKitDisabled() {
        let state = CloudSyncMonitor.initialState(cloudKitEnabled: false, isSignedIntoiCloud: true, hasExistingData: true)
        #expect(state == .unavailable)
    }

    @Test func unavailableWhenNotSignedIntoiCloud() {
        let state = CloudSyncMonitor.initialState(cloudKitEnabled: true, isSignedIntoiCloud: false, hasExistingData: true)
        #expect(state == .unavailable)
    }

    @Test func importingWhenEnabledSignedInButNoLocalData() {
        let state = CloudSyncMonitor.initialState(cloudKitEnabled: true, isSignedIntoiCloud: true, hasExistingData: false)
        #expect(state == .importing)
    }

    @Test func normalWhenEnabledSignedInWithLocalData() {
        let state = CloudSyncMonitor.initialState(cloudKitEnabled: true, isSignedIntoiCloud: true, hasExistingData: true)
        #expect(state == .normal)
    }

    @Test func initUsesInitialStateRule() {
        let monitor = CloudSyncMonitor(cloudKitEnabled: true, isSignedIntoiCloud: true, hasExistingData: false)
        #expect(monitor.state == .importing)
        #expect(monitor.exportStatus == .idle)
    }

    @Test func nextStateIgnoresNonImportEvents() {
        let result = CloudSyncMonitor.nextState(current: .importing, eventType: .export, isFinished: true, succeeded: true)
        #expect(result == .importing)
    }

    @Test func nextStateIgnoresUnfinishedImport() {
        let result = CloudSyncMonitor.nextState(current: .importing, eventType: .import, isFinished: false, succeeded: true)
        #expect(result == .importing)
    }

    @Test func nextStateMovesToNormalOnSuccessfulImportCompletion() {
        let result = CloudSyncMonitor.nextState(current: .importing, eventType: .import, isFinished: true, succeeded: true)
        #expect(result == .normal)
    }

    @Test func nextStateMovesToUnavailableOnFailedImportCompletion() {
        let result = CloudSyncMonitor.nextState(current: .importing, eventType: .import, isFinished: true, succeeded: false)
        #expect(result == .unavailable)
    }

    @Test func nextExportStatusIgnoresImportEvents() {
        let result = CloudSyncMonitor.nextExportStatus(
            current: .failed(reason: "이전 오류"), eventType: .import, isFinished: true, succeeded: true, errorDescription: nil)
        #expect(result == .failed(reason: "이전 오류"))
    }

    @Test func nextExportStatusUploadingWhileExportInFlight() {
        let result = CloudSyncMonitor.nextExportStatus(
            current: .idle, eventType: .export, isFinished: false, succeeded: false, errorDescription: nil)
        #expect(result == .uploading)
    }

    @Test func nextExportStatusIdleAfterSuccessfulExport() {
        let result = CloudSyncMonitor.nextExportStatus(
            current: .uploading, eventType: .export, isFinished: true, succeeded: true, errorDescription: nil)
        #expect(result == .idle)
    }

    @Test func nextExportStatusFailedWithReasonAfterFailedExport() {
        let result = CloudSyncMonitor.nextExportStatus(
            current: .uploading, eventType: .export, isFinished: true, succeeded: false,
            errorDescription: "Unknown field 'CD_isExcludedFromBudget'")
        #expect(result == .failed(reason: "Unknown field 'CD_isExcludedFromBudget'"))
    }

    @Test func nextExportStatusFailedWithFallbackReasonWhenErrorDescriptionMissing() {
        let result = CloudSyncMonitor.nextExportStatus(
            current: .uploading, eventType: .export, isFinished: true, succeeded: false, errorDescription: nil)
        #expect(result == .failed(reason: "알 수 없는 오류"))
    }

    @Test func recheckedStateStaysUnavailableWhenCloudKitDisabled() {
        let result = CloudSyncMonitor.recheckedState(current: .unavailable, cloudKitEnabled: false, isSignedIntoiCloud: true, hasExistingData: true)
        #expect(result == .unavailable)
    }

    @Test func recheckedStateStaysUnavailableWhenStillNotSignedIn() {
        let result = CloudSyncMonitor.recheckedState(current: .unavailable, cloudKitEnabled: true, isSignedIntoiCloud: false, hasExistingData: true)
        #expect(result == .unavailable)
    }

    @Test func recheckedStateMovesToImportingWhenNowSignedInWithoutExistingData() {
        let result = CloudSyncMonitor.recheckedState(current: .unavailable, cloudKitEnabled: true, isSignedIntoiCloud: true, hasExistingData: false)
        #expect(result == .importing)
    }

    @Test func recheckedStateMovesToNormalWhenNowSignedInWithExistingData() {
        let result = CloudSyncMonitor.recheckedState(current: .unavailable, cloudKitEnabled: true, isSignedIntoiCloud: true, hasExistingData: true)
        #expect(result == .normal)
    }

    @Test func recheckedStateLeavesNonUnavailableStatesUnchanged() {
        let result = CloudSyncMonitor.recheckedState(current: .normal, cloudKitEnabled: true, isSignedIntoiCloud: false, hasExistingData: false)
        #expect(result == .normal)
    }

    @Test func recheckSignInInstanceStaysUnavailableWithoutRealICloudAccount() {
        // 테스트 실행 환경에는 iCloud 계정이 로그인돼 있지 않으므로 결정적으로 unavailable을 유지한다.
        let monitor = CloudSyncMonitor(cloudKitEnabled: true, isSignedIntoiCloud: false, hasExistingData: false)
        monitor.recheckSignIn()
        #expect(monitor.state == .unavailable)
    }
}
