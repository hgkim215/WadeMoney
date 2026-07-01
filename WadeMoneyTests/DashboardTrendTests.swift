import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct DashboardTrendTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }
    func makeRepo() throws -> (LedgerRepository, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        return (LedgerRepository(context: container.mainContext), container)
    }

    @Test func monthTrendHasSixBarsCurrentLast() throws {
        let (repo, container) = try makeRepo()
        let food = try repo.allCategories(includeArchived: false).first { $0.name == "식비" }!.id
        try repo.addTransaction(amount: 50_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 3))
        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc)
        vm.kind = .month
        vm.load()
        let d = try #require(vm.display)
        #expect(d.trend.count == 6)
        #expect(d.trend.last?.isCurrent == true)
        #expect(d.trend.last?.label == "7월")
        _ = container
    }
}
