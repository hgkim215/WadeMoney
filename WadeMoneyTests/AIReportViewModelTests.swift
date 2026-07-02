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

    @Test func computesSummaryProjectionAndCategoryChanges() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(300_000, for: YearMonth(year: 2026, month: 7))
        let food = try catID(repo, "식비"); let cafe = try catID(repo, "카페")
        try repo.addTransaction(amount: 50_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 6, 5))
        try repo.addTransaction(amount: 100_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))
        try repo.addTransaction(amount: 40_000, type: .expense, categoryID: cafe, memo: nil, date: date(2026, 6, 6))
        try repo.addTransaction(amount: 10_000, type: .expense, categoryID: cafe, memo: nil, date: date(2026, 7, 6))

        let spy = SpyReportNarrator(result: .success(ReportNarration(summarySentence: "요약", tipSentence: "팁")))
        let vm = AIReportViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc, narrator: spy)
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
                                    narrator: SpyReportNarrator(result: .failure(AIError())))
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
                                    aiAvailability: FakeAIAvailability(isAvailable: true))
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
                                    aiAvailability: FakeAIAvailability(isAvailable: false))
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
                                    narrator: SpyReportNarrator(result: .success(ReportNarration(summarySentence: "s", tipSentence: "t"))))
        await vm.load()

        #expect(vm.display?.overBudgetText != nil)
        _ = container
    }
}
