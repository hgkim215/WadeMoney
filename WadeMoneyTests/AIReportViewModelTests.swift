import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct AIReportViewModelTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int, _ hh: Int = 0) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d; comps.hour = hh
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
    /// 테스트 간·실행 간 오염을 막기 위해 격리된 UserDefaults 스위트로 캐시를 만든다.
    func freshCache() -> ReportNarrationCache {
        ReportNarrationCache(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
    }

    @Test func computesSummaryProjectionAndCategoryChanges() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(300_000, for: YearMonth(year: 2026, month: 7))
        let food = try catID(repo, "식비"); let cafe = try catID(repo, "카페")
        try repo.addTransaction(amount: 50_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 6, 5))
        try repo.addTransaction(amount: 100_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))
        try repo.addTransaction(amount: 40_000, type: .expense, categoryID: cafe, memo: nil, date: date(2026, 6, 6))
        try repo.addTransaction(amount: 10_000, type: .expense, categoryID: cafe, memo: nil, date: date(2026, 7, 6))

        let spy = SpyReportNarrator(result: .success(ReportNarration(summarySentence: "요약", tipSentence: "팁")))
        let vm = AIReportViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc, narrator: spy, cache: freshCache())
        await vm.load()

        let d = try #require(vm.display)
        #expect(d.totalText == "110,000")
        #expect(d.summarySentence == "요약")
        #expect(d.tipSentence == "팁")
        #expect(d.changes.contains { $0.name == "식비" && $0.increased })
        #expect(d.changes.contains { $0.name == "카페" && !$0.increased })
        #expect(spy.lastInput?.monthLabel.contains("7월") == true)
        _ = container
    }

    @Test func summarySentenceNilWhenNarratorFailsButNumbersStillShow() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(300_000, for: YearMonth(year: 2026, month: 7))
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 50_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))

        let vm = AIReportViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc,
                                    narrator: SpyReportNarrator(result: .failure(AIError())), cache: freshCache())
        await vm.load()

        #expect(vm.display?.summarySentence == nil)
        #expect(vm.display?.tipSentence == nil)
        #expect(vm.display?.totalText == "50,000")
        _ = container
    }

    @Test func skipsNarrationWhenAIDisabledButNumbersStillShow() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(300_000, for: YearMonth(year: 2026, month: 7))
        try settings.setAIEnabled(false)
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 50_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))

        let spy = SpyReportNarrator(result: .success(ReportNarration(summarySentence: "요약", tipSentence: "팁")))
        let vm = AIReportViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc, narrator: spy,
                                    aiAvailability: FakeAIAvailability(isAvailable: true), cache: freshCache())
        await vm.load()

        #expect(spy.lastInput == nil)
        #expect(vm.display?.summarySentence == nil)
        #expect(vm.display?.tipSentence == nil)
        #expect(vm.display?.totalText == "50,000")
        _ = container
    }

    @Test func skipsNarrationWhenModelUnavailableButNumbersStillShow() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(300_000, for: YearMonth(year: 2026, month: 7))
        try settings.setAIEnabled(true)
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 50_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))

        let spy = SpyReportNarrator(result: .success(ReportNarration(summarySentence: "요약", tipSentence: "팁")))
        let vm = AIReportViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc, narrator: spy,
                                    aiAvailability: FakeAIAvailability(isAvailable: false), cache: freshCache())
        await vm.load()

        #expect(spy.lastInput == nil)
        #expect(vm.display?.summarySentence == nil)
        #expect(vm.display?.tipSentence == nil)
        #expect(vm.display?.totalText == "50,000")
        _ = container
    }

    @Test func overBudgetTextSetWhenProjectedExceedsBudget() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(30_000, for: YearMonth(year: 2026, month: 7))
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 100_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 1))

        let vm = AIReportViewModel(repository: repo, now: date(2026, 7, 1, 12), calendar: utc,
                                    narrator: SpyReportNarrator(result: .success(ReportNarration(summarySentence: "s", tipSentence: "t"))), cache: freshCache())
        await vm.load()

        #expect(vm.display?.overBudgetText != nil)
        _ = container
    }

    @Test func topIncreaseIsPickedByDeltaRatioNotBySpendRank() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(1_000_000, for: YearMonth(year: 2026, month: 7))
        let food = try catID(repo, "식비"); let cafe = try catID(repo, "카페"); let bus = try catID(repo, "교통")
        // 식비: 지출 최대지만 +10%. 카페: 지출은 작지만 +300% → "가장 많이 늘어난"은 카페여야 한다.
        try repo.addTransaction(amount: 100_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 6, 5))
        try repo.addTransaction(amount: 110_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))
        try repo.addTransaction(amount: 10_000, type: .expense, categoryID: cafe, memo: nil, date: date(2026, 6, 6))
        try repo.addTransaction(amount: 40_000, type: .expense, categoryID: cafe, memo: nil, date: date(2026, 7, 6))
        // 교통: -80% (최대 감소)
        try repo.addTransaction(amount: 50_000, type: .expense, categoryID: bus, memo: nil, date: date(2026, 6, 7))
        try repo.addTransaction(amount: 10_000, type: .expense, categoryID: bus, memo: nil, date: date(2026, 7, 7))

        let spy = SpyReportNarrator(result: .success(ReportNarration(summarySentence: "s", tipSentence: "t")))
        let vm = AIReportViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc, narrator: spy, cache: freshCache())
        await vm.load()

        #expect(spy.lastInput?.topIncrease?.name == "카페")
        #expect(spy.lastInput?.topDecrease?.name == "교통")
        _ = container
    }

    // MARK: - 성능 동작(2단계 표시·캐시)

    @Test func numbersShowBeforeNarrationCompletes() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(300_000, for: YearMonth(year: 2026, month: 7))
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 50_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))

        let gated = GatedReportNarrator(result: ReportNarration(summarySentence: "요약", tipSentence: "팁"))
        let vm = AIReportViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc, narrator: gated, cache: freshCache())

        let loading = Task { await vm.load() }
        // 내레이션이 아직 진행 중일 때 숫자는 이미 표시되어야 한다.
        for _ in 0..<10_000 where vm.display == nil { await Task.yield() }
        let d = try #require(vm.display)
        #expect(d.totalText == "50,000")
        #expect(d.summarySentence == nil)
        #expect(gated.started)

        gated.open()
        await loading.value
        #expect(vm.display?.summarySentence == "요약")
        #expect(vm.display?.tipSentence == "팁")
        #expect(vm.isNarrating == false)
        _ = container
    }

    @Test func narrationServedFromCacheWithoutSecondAICall() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(300_000, for: YearMonth(year: 2026, month: 7))
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 50_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))

        let spy = SpyReportNarrator(result: .success(ReportNarration(summarySentence: "요약", tipSentence: "팁")))
        let cache = freshCache()
        let vm1 = AIReportViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc, narrator: spy, cache: cache)
        await vm1.load()
        #expect(spy.callCount == 1)

        // 데이터가 안 변했으면 두 번째 로드는 캐시로 즉시 채워지고 AI를 다시 호출하지 않는다.
        let vm2 = AIReportViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc, narrator: spy, cache: cache)
        await vm2.load()
        #expect(spy.callCount == 1)
        #expect(vm2.display?.summarySentence == "요약")
        #expect(vm2.display?.tipSentence == "팁")
        _ = container
    }

    @Test func narrationRegeneratedWhenDataChanges() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(300_000, for: YearMonth(year: 2026, month: 7))
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 50_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))

        let spy = SpyReportNarrator(result: .success(ReportNarration(summarySentence: "요약", tipSentence: "팁")))
        let cache = freshCache()
        await AIReportViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc, narrator: spy, cache: cache).load()
        #expect(spy.callCount == 1)

        // 거래가 추가되면(입력 변경) 캐시 미스 → 다시 생성한다.
        try repo.addTransaction(amount: 30_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 10))
        await AIReportViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc, narrator: spy, cache: cache).load()
        #expect(spy.callCount == 2)
        _ = container
    }

    @Test func prewarmCalledOnInitWhenModelAvailable() async throws {
        let (repo, _, container) = try makeRepo()
        let spy = SpyReportNarrator(result: .success(ReportNarration(summarySentence: "s", tipSentence: "t")))
        _ = AIReportViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc, narrator: spy,
                              aiAvailability: FakeAIAvailability(isAvailable: true), cache: freshCache())
        #expect(spy.prewarmCount == 1)

        _ = AIReportViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc, narrator: spy,
                              aiAvailability: FakeAIAvailability(isAvailable: false), cache: freshCache())
        #expect(spy.prewarmCount == 1)   // 모델이 없으면 프리웜하지 않는다
        _ = container
    }
}
