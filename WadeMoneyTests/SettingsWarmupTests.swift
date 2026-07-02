import Foundation
import SwiftData
import Testing
@testable import WadeMoney

@MainActor
struct SettingsWarmupTests {
    @Test func dashboardSummaryDoesNotDuplicateSettingsRowOnRepeatedCalls() throws {
        let container = try PersistenceController.makeInMemoryContainer()
        let ctx = container.mainContext
        try CategorySeeder.seedIfNeeded(ctx)
        // 앱 시작 시 하는 것처럼 설정을 미리 시드한다.
        _ = try SettingsStore(context: ctx).settingsModel()

        let repo = LedgerRepository(context: ctx)
        let cal = Calendar(identifier: .gregorian)
        _ = try repo.dashboardSummary(kind: .month, offset: 0, now: Date(timeIntervalSince1970: 1_800_000_000), calendar: cal)
        _ = try repo.dashboardSummary(kind: .month, offset: 0, now: Date(timeIntervalSince1970: 1_800_000_000), calendar: cal)

        let count = try ctx.fetchCount(FetchDescriptor<AppSettingsModel>())
        #expect(count == 1)
        _ = container
    }
}
