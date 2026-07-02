import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct PeriodScopedFetchTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }
    func repo() throws -> (LedgerRepository, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        return (LedgerRepository(context: container.mainContext), container)
    }
    func catID(_ r: LedgerRepository, _ n: String) throws -> UUID {
        try r.allCategories(includeArchived: false).first { $0.name == n }!.id
    }

    @Test func transactionsFromToIsHalfOpenAndExcludesOutside() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비")
        try r.addTransaction(amount: 1000, type: .expense, categoryID: food, memo: nil, date: date(2024, 1, 1))   // 훨씬 과거, 범위 밖
        try r.addTransaction(amount: 2000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))   // 범위 안
        try r.addTransaction(amount: 3000, type: .expense, categoryID: food, memo: nil, date: date(2026, 8, 1))   // 범위 끝(제외, 반열림)
        let result = try r.transactions(from: date(2026, 7, 1), to: date(2026, 8, 1))
        #expect(result.map(\.amount) == [2000])
        _ = c
    }

    @Test func dashboardSummaryUnchangedWithFarPastNoiseData() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비")
        // 2년 전 잡음 데이터 — 기간별 fetch로 바뀌어도 결과에 영향 없어야 함.
        try r.addTransaction(amount: 999_999, type: .expense, categoryID: food, memo: nil, date: date(2024, 1, 1))
        try r.addTransaction(amount: 80_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 6, 5))   // 지난달(페이스 비교용)
        try r.addTransaction(amount: 100_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5)) // 이번달

        let s = try r.dashboardSummary(kind: .month, offset: 0, now: date(2026, 7, 15), calendar: utc)
        #expect(s.totalExpense == 100_000)          // 2년 전 잡음이 섞이지 않음
        #expect(s.pace?.priorCumulative == 80_000)  // 지난달 데이터는 페이스 계산에 포함됨
        _ = c
    }
}
