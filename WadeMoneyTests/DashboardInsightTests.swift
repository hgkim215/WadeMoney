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

    @Test func showsAIReportEntryWhenEnabledAndAvailable() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setAIEnabled(true)

        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc,
                                     aiAvailability: FakeAIAvailability(isAvailable: true),
                                     insightGenerator: FakeInsightGenerator())

        #expect(vm.showsAIReportEntry == true)
        _ = container
    }

    @Test func hidesAIReportEntryWhenAIDisabled() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setAIEnabled(false)

        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc,
                                     aiAvailability: FakeAIAvailability(isAvailable: true),
                                     insightGenerator: FakeInsightGenerator())

        #expect(vm.showsAIReportEntry == false)
        _ = container
    }

    @Test func hidesAIReportEntryWhenModelUnavailable() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setAIEnabled(true)

        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc,
                                     aiAvailability: FakeAIAvailability(isAvailable: false),
                                     insightGenerator: FakeInsightGenerator())

        #expect(vm.showsAIReportEntry == false)
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

    @Test func supersededInsightRefreshDoesNotOverwriteNewerResult() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setAIEnabled(true)
        try seedComparablePace(repo)

        let gate = SteppableInsightGate()
        let generator = SteppableInsightGenerator(gate: gate, firstResult: "오래된 결과", secondResult: "최신 결과")

        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc,
                                     aiAvailability: FakeAIAvailability(isAvailable: true),
                                     insightGenerator: generator)
        vm.kind = .month
        vm.load()

        // Start a first refresh and let it suspend inside generate() (simulating a slow
        // real Foundation Models call), then start a second refresh before it resolves.
        let staleTask = Task { await vm.refreshInsight() }
        while await gate.firstCallStarted == false { await Task.yield() }

        await vm.refreshInsight()
        #expect(vm.insightText == "최신 결과")

        // Now let the superseded first call resolve. Its (stale) result must not
        // clobber the newer one that already landed.
        await gate.release()
        await staleTask.value

        #expect(vm.insightText == "최신 결과")
        _ = container
    }

    @Test func guardFailureAfterCancellingInFlightRefreshResetsLoadingFlag() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setAIEnabled(true)
        try seedComparablePace(repo)

        let gate = SteppableInsightGate()
        let generator = SteppableInsightGenerator(gate: gate, firstResult: "오래된 결과", secondResult: "최신 결과")

        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc,
                                     aiAvailability: FakeAIAvailability(isAvailable: true),
                                     insightGenerator: generator)
        vm.kind = .month
        vm.load()

        // First refresh passes the guard and suspends in-flight (isLoadingInsight becomes true).
        let staleTask = Task { await vm.refreshInsight() }
        while await gate.firstCallStarted == false { await Task.yield() }

        // Switch to a period with no comparable pace so the *second* refresh's own
        // guard fails — this is the branch that must also reset isLoadingInsight.
        vm.kind = .day
        vm.load()
        await vm.refreshInsight()

        #expect(vm.insightText == nil)
        #expect(vm.isLoadingInsight == false)

        await gate.release()
        await staleTask.value

        #expect(vm.isLoadingInsight == false)
        _ = container
    }
}

private actor SteppableInsightGate {
    private(set) var firstCallStarted = false
    private var continuation: CheckedContinuation<Void, Never>?

    func markFirstCallStarted() {
        firstCallStarted = true
    }

    func waitForRelease() async {
        await withCheckedContinuation { continuation = $0 }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

private actor SteppableInsightGenerator: InsightGenerating {
    private let gate: SteppableInsightGate
    private let firstResult: String
    private let secondResult: String
    private var callCount = 0

    init(gate: SteppableInsightGate, firstResult: String, secondResult: String) {
        self.gate = gate
        self.firstResult = firstResult
        self.secondResult = secondResult
    }

    func generate(_ input: InsightInput) async throws -> String {
        callCount += 1
        guard callCount == 1 else { return secondResult }
        await gate.markFirstCallStarted()
        await gate.waitForRelease()
        return firstResult
    }
}
