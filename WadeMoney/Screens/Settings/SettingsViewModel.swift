import Foundation
import Observation
import WadeMoneyCore

@MainActor
@Observable
final class SettingsViewModel {
    private let settingsStore: SettingsStore
    private let categoryStore: CategoryStore
    private let now: Date
    private let calendar: Calendar

    private(set) var budget: Decimal = 0
    private(set) var budgetText: String = "0"
    private(set) var monthStartDayText: String = "매월 1일"
    private(set) var aiEnabled: Bool = true
    private(set) var categoryCountText: String = "0개"

    init(settingsStore: SettingsStore, categoryStore: CategoryStore, now: Date, calendar: Calendar) {
        self.settingsStore = settingsStore
        self.categoryStore = categoryStore
        self.now = now
        self.calendar = calendar
    }

    private var currentYearMonth: YearMonth {
        YearMonth(year: calendar.component(.year, from: now), month: calendar.component(.month, from: now))
    }

    func load() {
        let settings = (try? settingsStore.settings()) ?? EngineSettings()
        aiEnabled = settings.aiEnabled
        monthStartDayText = "매월 \(settings.monthStartDay)일"
        let book = try? settingsStore.budgetBook()
        let amount = book?.amount(for: currentYearMonth) ?? 0
        budget = amount
        budgetText = Won.string(amount)
        let count = (try? categoryStore.active().count) ?? 0
        categoryCountText = "\(count)개"
    }

    func setBudget(_ amount: Decimal) {
        try? settingsStore.setMonthlyBudget(amount, for: currentYearMonth)
        load()
    }

    func toggleAI() {
        try? settingsStore.setAIEnabled(!aiEnabled)
        load()
    }
}
