import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct SettingsStoreTests {
    func store() throws -> (SettingsStore, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        return (SettingsStore(context: container.mainContext), container)
    }

    @Test func settingsCreatesSingletonWithDefaults() throws {
        let (s, container) = try store()
        let es = try s.settings()
        #expect(es.monthStartDay == 1)
        #expect(es.aiEnabled == true)
        // 두 번째 호출도 새 레코드를 만들지 않음
        _ = try s.settings()
        let model = try s.settingsModel()
        #expect(model.monthStartDay == 1)
        _ = container
    }

    @Test func appearanceDefaultsToSystemAndPersists() throws {
        let (s, container) = try store()
        #expect(try s.appearance() == .system)
        try s.setAppearance(.dark)
        #expect(try s.appearance() == .dark)
        _ = container
    }

    @Test func duplicateSettingsRowsResolveDeterministicallyAndMergeSeedFlag() throws {
        // CloudKit 병합으로 설정 행이 2개가 된 상황: id 최솟값 행이 승자, 시드 플래그는 합집합.
        let (s, container) = try store()
        let ctx = container.mainContext
        let a = AppSettingsModel(monthStartDay: 5, didSeedDefaultCategories: false)
        let b = AppSettingsModel(monthStartDay: 15, didSeedDefaultCategories: true)
        ctx.insert(a); ctx.insert(b)
        try ctx.save()

        let winner = try s.settingsModel()
        let expectedWinner = a.id < b.id ? a : b
        #expect(winner.id == expectedWinner.id)
        #expect(winner.didSeedDefaultCategories == true)   // 어느 행에 있었든 플래그 유지
        #expect(try ctx.fetchCount(FetchDescriptor<AppSettingsModel>()) == 1)   // 중복 치유됨
        // 이후 읽기/쓰기가 항상 같은 행을 향한다
        try s.setMonthStartDay(20)
        #expect(try s.settings().monthStartDay == 20)
        _ = container
    }

    @Test func duplicateBudgetRowsForSameMonthAreHealedOnWrite() throws {
        let (s, container) = try store()
        let ctx = container.mainContext
        ctx.insert(MonthlyBudgetModel(effectiveYear: 2026, effectiveMonth: 7, amount: 100_000))
        ctx.insert(MonthlyBudgetModel(effectiveYear: 2026, effectiveMonth: 7, amount: 200_000))
        try ctx.save()

        try s.setMonthlyBudget(300_000, for: YearMonth(year: 2026, month: 7))
        #expect(try ctx.fetchCount(FetchDescriptor<MonthlyBudgetModel>()) == 1)
        #expect(try s.budgetBook().amount(for: YearMonth(year: 2026, month: 7)) == 300_000)
        _ = container
    }

    @Test func budgetBookPicksDeterministicRowAmongDuplicates() throws {
        let (s, container) = try store()
        let ctx = container.mainContext
        let x = MonthlyBudgetModel(effectiveYear: 2026, effectiveMonth: 7, amount: 100_000)
        let y = MonthlyBudgetModel(effectiveYear: 2026, effectiveMonth: 7, amount: 200_000)
        ctx.insert(x); ctx.insert(y)
        try ctx.save()

        let expected = x.id < y.id ? x.amount : y.amount
        #expect(try s.budgetBook().amount(for: YearMonth(year: 2026, month: 7)) == expected)
        _ = container
    }

    @Test func setMonthlyBudgetInsertsThenUpdatesSameMonth() throws {
        let (s, container) = try store()
        try s.setMonthlyBudget(1_000_000, for: YearMonth(year: 2026, month: 7))
        try s.setMonthlyBudget(1_300_000, for: YearMonth(year: 2026, month: 7)) // 갱신
        try s.setMonthlyBudget(1_500_000, for: YearMonth(year: 2026, month: 8)) // 신규
        let book = try s.budgetBook()
        #expect(book.amount(for: YearMonth(year: 2026, month: 7)) == 1_300_000)
        #expect(book.amount(for: YearMonth(year: 2026, month: 8)) == 1_500_000)
        #expect(book.amount(for: YearMonth(year: 2026, month: 6)) == nil)
        _ = container
    }
}
