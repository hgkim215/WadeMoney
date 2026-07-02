import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct DashboardInsightTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }
    func makeRepo() throws -> (LedgerRepository, SettingsStore, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        let ctx = container.mainContext
        try CategorySeeder.seedIfNeeded(ctx)
        return (LedgerRepository(context: ctx), SettingsStore(context: ctx), container)
    }
    func catID(_ repo: LedgerRepository, _ name: String) throws -> UUID {
        try repo.allCategories(includeArchived: false).first { $0.name == name }!.id
    }
    func seedComparablePace(_ repo: LedgerRepository) throws {
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 80_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 6, 5))
        try repo.addTransaction(amount: 100_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))
    }

    @Test func loadsInsightWhenEnabledAvailableAndComparable() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setAIEnabled(true)
        try seedComparablePace(repo)

        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc,
                                     aiAvailability: FakeAIAvailability(isAvailable: true),
                                     insightGenerator: FakeInsightGenerator(result: .success("테스트 인사이트 문장")))
        vm.kind = .month
        vm.load()
        await vm.refreshInsight()

        #expect(vm.insightText == "테스트 인사이트 문장")
        #expect(vm.insightIsGood == false) // 지출 증가 → 주의
        _ = container
    }

    @Test func hidesInsightWhenAIDisabled() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setAIEnabled(false)
        try seedComparablePace(repo)

        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc,
                                     aiAvailability: FakeAIAvailability(isAvailable: true),
                                     insightGenerator: FakeInsightGenerator(result: .success("숨겨져야 함")))
        vm.kind = .month
        vm.load()
        await vm.refreshInsight()

        #expect(vm.insightText == nil)
        _ = container
    }

    @Test func hidesInsightWhenModelUnavailable() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setAIEnabled(true)
        try seedComparablePace(repo)

        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc,
                                     aiAvailability: FakeAIAvailability(isAvailable: false),
                                     insightGenerator: FakeInsightGenerator(result: .success("숨겨져야 함")))
        vm.kind = .month
        vm.load()
        await vm.refreshInsight()

        #expect(vm.insightText == nil)
        _ = container
    }

    @Test func hidesInsightOnDayViewNoPace() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setAIEnabled(true)
        try seedComparablePace(repo)

        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc,
                                     aiAvailability: FakeAIAvailability(isAvailable: true),
                                     insightGenerator: FakeInsightGenerator(result: .success("숨겨져야 함")))
        vm.kind = .day
        vm.load()
        await vm.refreshInsight()

        #expect(vm.insightText == nil)
        _ = container
    }

    @Test func fallsBackSilentlyOnGenerationFailure() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setAIEnabled(true)
        try seedComparablePace(repo)

        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc,
                                     aiAvailability: FakeAIAvailability(isAvailable: true),
                                     insightGenerator: FakeInsightGenerator(result: .failure(AIError())))
        vm.kind = .month
        vm.load()
        await vm.refreshInsight()

        #expect(vm.insightText == nil)
        _ = container
    }
}
