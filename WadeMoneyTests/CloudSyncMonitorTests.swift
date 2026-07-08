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
        #expect(monitor.pendingExport == false)
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

    @Test func nextPendingExportIgnoresImportEvents() {
        let result = CloudSyncMonitor.nextPendingExport(current: true, eventType: .import, isFinished: true, succeeded: true)
        #expect(result == true)
    }

    @Test func nextPendingExportTrueWhileExportInFlight() {
        let result = CloudSyncMonitor.nextPendingExport(current: false, eventType: .export, isFinished: false, succeeded: false)
        #expect(result == true)
    }

    @Test func nextPendingExportFalseAfterSuccessfulExport() {
        let result = CloudSyncMonitor.nextPendingExport(current: true, eventType: .export, isFinished: true, succeeded: true)
        #expect(result == false)
    }

    @Test func nextPendingExportStaysTrueAfterFailedExport() {
        let result = CloudSyncMonitor.nextPendingExport(current: true, eventType: .export, isFinished: true, succeeded: false)
        #expect(result == true)
    }
}
