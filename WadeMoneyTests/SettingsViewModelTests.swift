import Foundation
import SwiftData
import Testing
import UserNotifications
import WadeMoneyCore
@testable import WadeMoney

final class FakeNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    var authorizationGranted = true
    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var scheduledHour: Int?
    var scheduledMinute: Int?
    var cancelCallCount = 0

    func requestAuthorization() async -> Bool { authorizationGranted }
    func currentAuthorizationStatus() async -> UNAuthorizationStatus { authorizationStatus }
    func schedule(hour: Int, minute: Int) {
        scheduledHour = hour
        scheduledMinute = minute
    }
    func cancel() { cancelCallCount += 1 }
}

@MainActor
struct SettingsViewModelTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }
    func vm() throws -> (SettingsViewModel, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        let ctx = container.mainContext
        let vm = SettingsViewModel(settingsStore: SettingsStore(context: ctx),
                                   categoryStore: CategoryStore(context: ctx),
                                   now: date(2026, 7, 15), calendar: utc)
        return (vm, container)
    }
    func vm(scheduler: NotificationScheduling) throws -> (SettingsViewModel, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        let ctx = container.mainContext
        let vm = SettingsViewModel(settingsStore: SettingsStore(context: ctx),
                                   categoryStore: CategoryStore(context: ctx),
                                   now: date(2026, 7, 15), calendar: utc,
                                   notificationScheduler: scheduler)
        return (vm, container)
    }

    @Test func loadsBudgetAndCategoryCount() throws {
        let (vm, c) = try vm()
        vm.setBudget(1_300_000)
        vm.load()
        #expect(vm.budgetText == "1,300,000")
        #expect(vm.categoryCountText == "8개")
        _ = c
    }

    @Test func budgetRowTextShowsUnsetWhenZero() throws {
        let (vm, c) = try vm()
        vm.load()
        #expect(vm.budgetRowText == "설정 안 함")   // 시드 직후 기본값

        vm.setBudget(500_000)
        #expect(vm.budgetRowText == "₩500,000")

        vm.setBudget(0)   // "예산 설정 안 함" 선택
        #expect(vm.budgetRowText == "설정 안 함")
        _ = c
    }

    @Test func toggleAIPersists() throws {
        let (vm, c) = try vm()
        vm.load()
        let initial = vm.aiEnabled
        vm.toggleAI()
        #expect(vm.aiEnabled == !initial)
        // reload reflects persisted value
        vm.load()
        #expect(vm.aiEnabled == !initial)
        _ = c
    }

    @Test func setMonthStartDayPersistsAndReloadsText() throws {
        let (vm, c) = try vm()
        vm.load()
        vm.setMonthStartDay(15)
        #expect(vm.monthStartDay == 15)
        #expect(vm.monthStartDayText == "매월 15일")
        _ = c
    }

    @Test func dailyReminderDefaultsToDisabledWithDefaultTime() throws {
        let (vm, c) = try vm()
        vm.load()
        #expect(vm.dailyReminderEnabled == false)
        #expect(vm.dailyReminderHour == 22)
        #expect(vm.dailyReminderMinute == 0)
        #expect(vm.dailyReminderTimeText == "오후 10:00")
        _ = c
    }

    @Test func enablingReminderRequestsAuthorizationAndSchedulesOnGrant() async throws {
        let fake = FakeNotificationScheduler()
        fake.authorizationGranted = true
        let (vm, c) = try vm(scheduler: fake)
        vm.load()
        let succeeded = await vm.setDailyReminderEnabled(true)
        #expect(succeeded == true)
        #expect(vm.dailyReminderEnabled == true)
        #expect(fake.scheduledHour == 22)
        #expect(fake.scheduledMinute == 0)
        _ = c
    }

    @Test func enablingReminderStaysOffWhenAuthorizationDenied() async throws {
        let fake = FakeNotificationScheduler()
        fake.authorizationGranted = false
        let (vm, c) = try vm(scheduler: fake)
        vm.load()
        let succeeded = await vm.setDailyReminderEnabled(true)
        #expect(succeeded == false)
        #expect(vm.dailyReminderEnabled == false)
        #expect(fake.scheduledHour == nil)
        _ = c
    }

    @Test func disablingReminderCancelsSchedule() async throws {
        let fake = FakeNotificationScheduler()
        fake.authorizationGranted = true
        let (vm, c) = try vm(scheduler: fake)
        vm.load()
        _ = await vm.setDailyReminderEnabled(true)
        _ = await vm.setDailyReminderEnabled(false)
        #expect(vm.dailyReminderEnabled == false)
        #expect(fake.cancelCallCount == 1)
        _ = c
    }

    @Test func setDailyReminderTimePersistsAndReschedules() throws {
        let fake = FakeNotificationScheduler()
        let (vm, c) = try vm(scheduler: fake)
        vm.load()
        vm.setDailyReminderTime(hour: 9, minute: 30)
        #expect(vm.dailyReminderHour == 9)
        #expect(vm.dailyReminderMinute == 30)
        #expect(vm.dailyReminderTimeText == "오전 9:30")
        #expect(fake.scheduledHour == 9)
        #expect(fake.scheduledMinute == 30)
        _ = c
    }

    @Test func reconcilePermissionTurnsDisplayOffWhenOSPermissionRevoked() async throws {
        let fake = FakeNotificationScheduler()
        fake.authorizationGranted = true
        let (vm, c) = try vm(scheduler: fake)
        vm.load()
        _ = await vm.setDailyReminderEnabled(true)
        #expect(vm.dailyReminderEnabled == true)

        fake.authorizationStatus = .denied
        await vm.reconcilePermission()
        #expect(vm.dailyReminderEnabled == false)
        _ = c
    }
}
