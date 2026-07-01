import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct LedgerRepositoryTests {
    /// 결정적 UTC 캘린더.
    var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }

    func freshRepo() throws -> (LedgerRepository, SettingsStore, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        let ctx = container.mainContext
        try CategorySeeder.seedIfNeeded(ctx)
        return (LedgerRepository(context: ctx), SettingsStore(context: ctx), container)
    }

    func categoryID(_ repo: LedgerRepository, _ name: String) throws -> UUID {
        try repo.allCategories(includeArchived: false).first { $0.name == name }!.id
    }

    @Test func addAndFetchTransaction() throws {
        let (repo, _, container) = try freshRepo()
        let cafe = try categoryID(repo, "카페")
        try repo.addTransaction(amount: 4800, type: .expense, categoryID: cafe, memo: "아메", date: date(2026, 7, 3))
        let all = try repo.allTransactions()
        #expect(all.count == 1)
        #expect(all[0].categoryID == cafe)
        #expect(all[0].amount == 4800)
        _ = container
    }

    @Test func deleteTransactionRemovesIt() throws {
        let (repo, _, container) = try freshRepo()
        let food = try categoryID(repo, "식비")
        try repo.addTransaction(amount: 9000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 2))
        let id = try repo.allTransactions()[0].id
        try repo.deleteTransaction(id: id)
        #expect(try repo.allTransactions().isEmpty)
        _ = container
    }

    @Test func dashboardSummaryComposesEngine() throws {
        let (repo, settings, container) = try freshRepo()
        try settings.setMonthlyBudget(1_000_000, for: YearMonth(year: 2026, month: 7))
        let food = try categoryID(repo, "식비")
        let cafe = try categoryID(repo, "카페")
        try repo.addTransaction(amount: 100_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))
        try repo.addTransaction(amount: 60_000, type: .expense, categoryID: cafe, memo: nil, date: date(2026, 7, 6))
        try repo.addTransaction(amount: 45_000, type: .income, categoryID: nil, memo: "환급", date: date(2026, 7, 7))

        let s = try repo.dashboardSummary(kind: .month, offset: 0, now: date(2026, 7, 15), calendar: utc)
        #expect(s.totalExpense == 160_000)              // 수입 45,000 제외
        #expect(s.budget == 1_000_000)
        #expect(s.remaining == 840_000)
        #expect(s.donut.count == 2)                      // 식비, 카페
        #expect(s.donut.first?.total == 100_000)         // 최대 먼저
        #expect(s.pace != nil)
        _ = container
    }
}
