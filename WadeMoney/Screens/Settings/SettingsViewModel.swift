import Foundation
import Observation
import UserNotifications
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
    private(set) var dailyReminderEnabled: Bool = false
    private(set) var dailyReminderHour: Int = 22
    private(set) var dailyReminderMinute: Int = 0
    var dailyReminderTimeText: String { formatReminderTime(hour: dailyReminderHour, minute: dailyReminderMinute) }

    private let notificationScheduler: NotificationScheduling

    init(
        settingsStore: SettingsStore,
        categoryStore: CategoryStore,
        now: Date,
        calendar: Calendar,
        notificationScheduler: NotificationScheduling = DailyReminderScheduler()
    ) {
        self.settingsStore = settingsStore
        self.categoryStore = categoryStore
        self.now = now
        self.calendar = calendar
        self.notificationScheduler = notificationScheduler
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
        if let model = try? settingsStore.settingsModel() {
            dailyReminderEnabled = model.dailyReminderEnabled
            dailyReminderHour = model.dailyReminderHour
            dailyReminderMinute = model.dailyReminderMinute
        }
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

    @discardableResult
    func setDailyReminderEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            guard await notificationScheduler.requestAuthorization() else { return false }
            try? settingsStore.setDailyReminder(enabled: true, hour: dailyReminderHour, minute: dailyReminderMinute)
            notificationScheduler.schedule(hour: dailyReminderHour, minute: dailyReminderMinute)
        } else {
            try? settingsStore.setDailyReminder(enabled: false, hour: dailyReminderHour, minute: dailyReminderMinute)
            notificationScheduler.cancel()
        }
        load()
        return true
    }

    func setDailyReminderTime(hour: Int, minute: Int) {
        try? settingsStore.setDailyReminder(enabled: true, hour: hour, minute: minute)
        notificationScheduler.schedule(hour: hour, minute: minute)
        load()
    }

    /// 마지막으로 저장된 설정은 그대로 두고, 표시상의 켜짐 상태만 실제 OS 권한 상태에 맞춘다 —
    /// 사용자가 iOS 설정에서 권한을 회수해도 저장된 선호도 자체는 덮어쓰지 않는다.
    func reconcilePermission() async {
        guard dailyReminderEnabled else { return }
        if await notificationScheduler.currentAuthorizationStatus() != .authorized {
            dailyReminderEnabled = false
        }
    }

    private func formatReminderTime(hour: Int, minute: Int) -> String {
        let period = hour < 12 ? "오전" : "오후"
        let displayHour = (1...12).contains(hour) ? hour : (hour == 0 ? 12 : hour - 12)
        return String(format: "%@ %d:%02d", period, displayHour, minute)
    }
}
