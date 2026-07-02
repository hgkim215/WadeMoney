import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct WidgetDataBuilderTests {
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

    @Test func summaryReflectsTodayExpenseAndMonthRemaining() throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(300_000, for: YearMonth(year: 2026, month: 7))
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 12_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 15))
        try repo.addTransaction(amount: 50_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 3))

        let data = WidgetDataBuilder.summary(repository: repo, now: date(2026, 7, 15), calendar: utc)
        #expect(data.todayExpenseText == "12,000")
        #expect(data.monthRemainingText == "238,000원 남음")
        #expect(data.consumedFraction != nil)
        _ = container
    }

    @Test func summaryHandlesNoBudgetGracefully() throws {
        let (repo, _, container) = try makeRepo()
        let data = WidgetDataBuilder.summary(repository: repo, now: date(2026, 7, 15), calendar: utc)
        #expect(data.todayExpenseText == "0")
        #expect(data.monthRemainingText == nil)
        _ = container
    }
}
