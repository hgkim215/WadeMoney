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
