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
    /// 0원은 "설정 안 함"을 뜻한다 — LedgerRepository의 예산 표시 규칙과 동일.
    var budgetRowText: String { budget > 0 ? "₩\(budgetText)" : "설정 안 함" }
    private(set) var monthStartDay: Int = 1
    private(set) var monthStartDayText: String = "매월 1일"
    private(set) var aiEnabled: Bool = true
    private(set) var categoryCountText: String = "0개"
    private(set) var appearance: AppAppearance = .system

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
        monthStartDay = settings.monthStartDay
        monthStartDayText = "매월 \(settings.monthStartDay)일"
        let book = try? settingsStore.budgetBook()
        let amount = book?.amount(for: currentYearMonth) ?? 0
        budget = amount
        budgetText = Won.string(amount)
        let count = (try? categoryStore.active().count) ?? 0
        categoryCountText = "\(count)개"
        appearance = (try? settingsStore.appearance()) ?? .system
    }

    func setAppearance(_ appearance: AppAppearance) {
        try? settingsStore.setAppearance(appearance)
        load()
    }

    func setBudget(_ amount: Decimal) {
        try? settingsStore.setMonthlyBudget(amount, for: currentYearMonth)
        load()
    }

    func setMonthStartDay(_ day: Int) {
        try? settingsStore.setMonthStartDay(day)
        load()
    }

    func toggleAI() {
        try? settingsStore.setAIEnabled(!aiEnabled)
        load()
    }
}
