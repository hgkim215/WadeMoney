import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct DashboardViewModelTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }

    /// 컨테이너를 보유(SwiftData dealloc 방지)한 채 시드된 리포지토리 반환.
    func makeRepo() throws -> (LedgerRepository, SettingsStore, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        let ctx = container.mainContext
        try CategorySeeder.seedIfNeeded(ctx)
        return (LedgerRepository(context: ctx), SettingsStore(context: ctx), container)
    }
    func catID(_ repo: LedgerRepository, _ name: String) throws -> UUID {
        try repo.allCategories(includeArchived: false).first { $0.name == name }!.id
    }

    @Test func buildsMonthDisplayWithPaceAndDonut() throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(1_000_000, for: YearMonth(year: 2026, month: 7))
        let food = try catID(repo, "식비"); let cafe = try catID(repo, "카페")
        // 지난달(6월) 지출이 있어야 페이스 비교(전월 동일시점)가 성립한다.
        try repo.addTransaction(amount: 80_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 6, 5))
        try repo.addTransaction(amount: 100_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))
        try repo.addTransaction(amount: 60_000, type: .expense, categoryID: cafe, memo: nil, date: date(2026, 7, 6))

        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc)
        vm.kind = .month
        vm.load()

        let d = try #require(vm.display)
        #expect(d.periodLabel == "2026년 7월")
        #expect(d.totalText == "160,000")
        #expect(d.budgetText == "1,000,000")
        #expect(d.remainText == "840,000")
        #expect(d.donut.count == 2)
        #expect(d.donut.first?.name == "식비")     // 최대 먼저
        #expect(d.pace != nil)                      // 월 뷰는 페이스 있음
        _ = container
    }

    @Test func dayViewHasNoPaceButHasDayBudget() throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(310_000, for: YearMonth(year: 2026, month: 7)) // 31일 → 일예산 10,000
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 3_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 15))

        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc)
        vm.kind = .day
        vm.load()

        let d = try #require(vm.display)
        #expect(d.pace == nil)
        #expect(d.dayBudget != nil)
        _ = container
    }
}
