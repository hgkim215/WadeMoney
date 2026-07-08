# Daily Expense Reminder Notification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users turn on a daily local notification ("오늘 지출 기록했나요?") at a time they choose in Settings, reminding them to log today's spending.

**Architecture:** `AppSettingsModel` gains 3 CloudKit-synced fields (enabled/hour/minute). A new `NotificationScheduling` protocol wraps `UNUserNotificationCenter` behind a small real implementation (`DailyReminderScheduler`) and a test fake, injected into `SettingsViewModel`. `SettingsScreen` gets a new "알림" section: a toggle (requests permission on enable) and a time row (opens a wheel-picker sheet, mirroring the existing `MonthStartDaySheet`).

**Tech Stack:** SwiftUI, SwiftData, `UserNotifications` framework (`UNUserNotificationCenter`, `UNCalendarNotificationTrigger`), Swift Testing.

## Global Constraints

- No skip-if-already-logged-today logic — the notification fires unconditionally every day at the configured time.
- No onboarding tour in this plan — the only entry point is the Settings screen.
- No foreground-presentation delegate/custom banner handling — default iOS behavior is sufficient.
- Default time when first enabled: **22:00** (오후 10:00).
- Notification identifier: `"daily-expense-reminder"`.
- Notification title: **"오늘 지출 기록했나요?"** — body: **"잊기 전에 오늘 쓴 돈을 기록해보세요"** (exact copy, do not paraphrase).
- Permission-denied toast copy: **"iOS 설정에서 알림 권한을 허용해주세요"** (reuses the existing `showSettingsToast` mechanism).
- Test simulator: **iPhone 17e** for all `xcodebuild test`/`build` commands.
- Spec: `docs/superpowers/specs/2026-07-08-daily-expense-reminder-notification-design.md`

---

### Task 1: `AppSettingsModel` + `SettingsStore` storage layer

**Files:**
- Modify: `WadeMoney/Models/AppSettingsModel.swift` (whole file — small, shown in full)
- Modify: `WadeMoney/Stores/SettingsStore.swift:70-75` (add a method after `setMonthStartDay`)
- Test: `WadeMoneyTests/SettingsStoreTests.swift`

**Interfaces:**
- Produces: `AppSettingsModel.dailyReminderEnabled: Bool` (default `false`), `.dailyReminderHour: Int` (default `22`), `.dailyReminderMinute: Int` (default `0`); `SettingsStore.setDailyReminder(enabled: Bool, hour: Int, minute: Int) throws`.

- [ ] **Step 1: Write the failing test**

Add to `WadeMoneyTests/SettingsStoreTests.swift`, after `appearanceDefaultsToSystemAndPersists`:

```swift
    @Test func dailyReminderDefaultsToDisabledAndPersistsWhenSet() throws {
        let (s, container) = try store()
        let model = try s.settingsModel()
        #expect(model.dailyReminderEnabled == false)
        #expect(model.dailyReminderHour == 22)
        #expect(model.dailyReminderMinute == 0)

        try s.setDailyReminder(enabled: true, hour: 21, minute: 30)
        let updated = try s.settingsModel()
        #expect(updated.dailyReminderEnabled == true)
        #expect(updated.dailyReminderHour == 21)
        #expect(updated.dailyReminderMinute == 30)
        _ = container
    }

    @Test func dailyReminderClampsHourAndMinuteToValidRanges() throws {
        let (s, container) = try store()
        try s.setDailyReminder(enabled: true, hour: 25, minute: 90)
        let model = try s.settingsModel()
        #expect(model.dailyReminderHour == 23)
        #expect(model.dailyReminderMinute == 59)

        try s.setDailyReminder(enabled: true, hour: -3, minute: -1)
        let model2 = try s.settingsModel()
        #expect(model2.dailyReminderHour == 0)
        #expect(model2.dailyReminderMinute == 0)
        _ = container
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/SettingsStoreTests`
Expected: FAIL — build error, `dailyReminderEnabled`/`setDailyReminder` not found.

- [ ] **Step 3: Add the fields to `AppSettingsModel`**

Replace the full contents of `WadeMoney/Models/AppSettingsModel.swift`:

```swift
import Foundation
import SwiftData

@Model
final class AppSettingsModel {
    var id: UUID = UUID()
    var monthStartDay: Int = 1
    var aiEnabled: Bool = true
    var didSeedDefaultCategories: Bool = false
    /// AppAppearance.rawValue (0=시스템, 1=라이트, 2=다크).
    var appearanceRaw: Int = 0
    var dailyReminderEnabled: Bool = false
    var dailyReminderHour: Int = 22
    var dailyReminderMinute: Int = 0

    init(
        id: UUID = UUID(),
        monthStartDay: Int = 1,
        aiEnabled: Bool = true,
        didSeedDefaultCategories: Bool = false,
        appearanceRaw: Int = 0,
        dailyReminderEnabled: Bool = false,
        dailyReminderHour: Int = 22,
        dailyReminderMinute: Int = 0
    ) {
        self.id = id
        self.monthStartDay = monthStartDay
        self.aiEnabled = aiEnabled
        self.didSeedDefaultCategories = didSeedDefaultCategories
        self.appearanceRaw = appearanceRaw
        self.dailyReminderEnabled = dailyReminderEnabled
        self.dailyReminderHour = dailyReminderHour
        self.dailyReminderMinute = dailyReminderMinute
    }
}
```

- [ ] **Step 4: Add `setDailyReminder` to `SettingsStore`**

In `WadeMoney/Stores/SettingsStore.swift`, insert after `setMonthStartDay` (currently lines 70-75):

```swift
    func setDailyReminder(enabled: Bool, hour: Int, minute: Int) throws {
        let model = try settingsModel()
        model.dailyReminderEnabled = enabled
        model.dailyReminderHour = min(max(hour, 0), 23)
        model.dailyReminderMinute = min(max(minute, 0), 59)
        try context.save()
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/SettingsStoreTests`
Expected: PASS — all `SettingsStoreTests` cases green, including the two new ones.

- [ ] **Step 6: Commit**

```bash
git add WadeMoney/Models/AppSettingsModel.swift WadeMoney/Stores/SettingsStore.swift WadeMoneyTests/SettingsStoreTests.swift
git commit -m "feat(notifications): add daily reminder fields to AppSettingsModel"
```

---

### Task 2: `NotificationScheduling` protocol + `DailyReminderScheduler`

**Files:**
- Create: `WadeMoney/Notifications/DailyReminderScheduler.swift`

**Interfaces:**
- Produces: `protocol NotificationScheduling { func requestAuthorization() async -> Bool; func currentAuthorizationStatus() async -> UNAuthorizationStatus; func schedule(hour: Int, minute: Int); func cancel() }`; `struct DailyReminderScheduler: NotificationScheduling` (real `UNUserNotificationCenter`-backed implementation); `DailyReminderScheduler.identifier: String` (static, `"daily-expense-reminder"`).
- Consumed by: Task 3 (`SettingsViewModel` takes a `NotificationScheduling` in its initializer).

**Note before starting:** This task has no automated test. `requestAuthorization()` triggers a real system permission dialog the first time it's called on a device/simulator, which cannot run unattended in `xcodebuild test`. Verification is: (a) the file builds cleanly (Step 2), and (b) a full manual check in Task 6 after the UI is wired up.

- [ ] **Step 1: Write the protocol and real implementation**

Create `WadeMoney/Notifications/DailyReminderScheduler.swift`:

```swift
import Foundation
import UserNotifications

protocol NotificationScheduling {
    func requestAuthorization() async -> Bool
    func currentAuthorizationStatus() async -> UNAuthorizationStatus
    func schedule(hour: Int, minute: Int)
    func cancel()
}

/// 매일 정해진 시각에 "오늘 지출 기록했나요?" 알림을 반복 예약한다.
/// UNCalendarNotificationTrigger(repeats: true)는 OS에 한 번 등록되면 앱 프로세스와 무관하게
/// 계속 반복되므로, 사용자가 설정을 바꿀 때만 schedule/cancel을 호출하면 된다 — 매 실행마다
/// 다시 예약할 필요는 없다.
struct DailyReminderScheduler: NotificationScheduling {
    static let identifier = "daily-expense-reminder"

    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func schedule(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "오늘 지출 기록했나요?"
        content.body = "잊기 전에 오늘 쓴 돈을 기록해보세요"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        // 같은 식별자로 다시 add하면 기존 대기 중인 요청을 교체한다 — 시각 변경 시 별도 cancel 불필요.
        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

Run: `xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add WadeMoney/Notifications/DailyReminderScheduler.swift
git commit -m "feat(notifications): add NotificationScheduling protocol and DailyReminderScheduler"
```

---

### Task 3: `SettingsViewModel` daily reminder state

**Files:**
- Modify: `WadeMoney/Screens/Settings/SettingsViewModel.swift` (whole file — shown in full)
- Test: `WadeMoneyTests/SettingsViewModelTests.swift`

**Interfaces:**
- Consumes: `NotificationScheduling`, `DailyReminderScheduler` (Task 2); `SettingsStore.setDailyReminder(enabled:hour:minute:)` (Task 1); `AppSettingsModel.dailyReminderEnabled/.dailyReminderHour/.dailyReminderMinute` (Task 1).
- Produces: `SettingsViewModel.init(settingsStore:categoryStore:now:calendar:notificationScheduler:)` (new trailing parameter, defaults to `DailyReminderScheduler()` so existing call sites keep compiling unchanged); `private(set) var dailyReminderEnabled: Bool`, `.dailyReminderHour: Int`, `.dailyReminderMinute: Int`, `var dailyReminderTimeText: String { get }`; `func setDailyReminderEnabled(_ enabled: Bool) async -> Bool` (returns whether the requested state actually took effect — `false` when turning on was denied permission); `func setDailyReminderTime(hour: Int, minute: Int)`; `func reconcilePermission() async`.

- [ ] **Step 1: Write the failing tests**

Add to `WadeMoneyTests/SettingsViewModelTests.swift`. First add this fake near the top of the file, right after the `struct SettingsViewModelTests {` opening brace's helper functions (after `vm()`):

```swift
    final class FakeNotificationScheduler: NotificationScheduling {
        var authorizationGranted = true
        var authorizationStatus: UNAuthorizationStatus = .authorized
        private(set) var scheduledHour: Int?
        private(set) var scheduledMinute: Int?
        private(set) var cancelCallCount = 0

        func requestAuthorization() async -> Bool { authorizationGranted }
        func currentAuthorizationStatus() async -> UNAuthorizationStatus { authorizationStatus }
        func schedule(hour: Int, minute: Int) { scheduledHour = hour; scheduledMinute = minute }
        func cancel() { cancelCallCount += 1 }
    }

    func vm(scheduler: FakeNotificationScheduler = FakeNotificationScheduler()) throws -> (SettingsViewModel, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        let ctx = container.mainContext
        let vm = SettingsViewModel(settingsStore: SettingsStore(context: ctx),
                                   categoryStore: CategoryStore(context: ctx),
                                   now: date(2026, 7, 15), calendar: utc,
                                   notificationScheduler: scheduler)
        return (vm, container)
    }
```

Then add `import UserNotifications` to the top of the file (after `import WadeMoneyCore`), and add these test cases at the end of the struct, before the closing `}`:

```swift
    @Test func dailyReminderDefaultsToDisabledWithDefaultTime() throws {
        let (vm, c) = try vm()
        vm.load()
        #expect(vm.dailyReminderEnabled == false)
        #expect(vm.dailyReminderTimeText == "오후 10:00")
        _ = c
    }

    @Test func enablingReminderRequestsAuthorizationAndSchedulesOnGrant() async throws {
        let scheduler = FakeNotificationScheduler()
        scheduler.authorizationGranted = true
        let (vm, c) = try vm(scheduler: scheduler)
        vm.load()

        let succeeded = await vm.setDailyReminderEnabled(true)

        #expect(succeeded == true)
        #expect(vm.dailyReminderEnabled == true)
        #expect(scheduler.scheduledHour == 22)
        #expect(scheduler.scheduledMinute == 0)
        _ = c
    }

    @Test func enablingReminderStaysOffWhenAuthorizationDenied() async throws {
        let scheduler = FakeNotificationScheduler()
        scheduler.authorizationGranted = false
        let (vm, c) = try vm(scheduler: scheduler)
        vm.load()

        let succeeded = await vm.setDailyReminderEnabled(true)

        #expect(succeeded == false)
        #expect(vm.dailyReminderEnabled == false)
        #expect(scheduler.scheduledHour == nil)
        _ = c
    }

    @Test func disablingReminderCancelsSchedule() async throws {
        let scheduler = FakeNotificationScheduler()
        let (vm, c) = try vm(scheduler: scheduler)
        vm.load()
        _ = await vm.setDailyReminderEnabled(true)

        let succeeded = await vm.setDailyReminderEnabled(false)

        #expect(succeeded == true)
        #expect(vm.dailyReminderEnabled == false)
        #expect(scheduler.cancelCallCount == 1)
        _ = c
    }

    @Test func setDailyReminderTimePersistsAndReschedules() throws {
        let scheduler = FakeNotificationScheduler()
        let (vm, c) = try vm(scheduler: scheduler)
        vm.load()

        vm.setDailyReminderTime(hour: 21, minute: 30)

        #expect(vm.dailyReminderHour == 21)
        #expect(vm.dailyReminderMinute == 30)
        #expect(vm.dailyReminderTimeText == "오후 9:30")
        #expect(scheduler.scheduledHour == 21)
        #expect(scheduler.scheduledMinute == 30)
        vm.load()
        #expect(vm.dailyReminderHour == 21)   // reload reflects persisted value
        _ = c
    }

    @Test func reconcilePermissionTurnsDisplayOffWhenOSPermissionRevoked() async throws {
        let scheduler = FakeNotificationScheduler()
        let (vm, c) = try vm(scheduler: scheduler)
        vm.load()
        _ = await vm.setDailyReminderEnabled(true)
        #expect(vm.dailyReminderEnabled == true)

        scheduler.authorizationStatus = .denied
        await vm.reconcilePermission()

        #expect(vm.dailyReminderEnabled == false)
        _ = c
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/SettingsViewModelTests`
Expected: FAIL — build error, `SettingsViewModel` has no `notificationScheduler` parameter / `dailyReminderEnabled` etc. not found.

- [ ] **Step 3: Implement the ViewModel changes**

Replace the full contents of `WadeMoney/Screens/Settings/SettingsViewModel.swift`:

```swift
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
    private let notificationScheduler: NotificationScheduling

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
    var dailyReminderTimeText: String { Self.formatReminderTime(hour: dailyReminderHour, minute: dailyReminderMinute) }

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

        let model = try? settingsStore.settingsModel()
        dailyReminderEnabled = model?.dailyReminderEnabled ?? false
        dailyReminderHour = model?.dailyReminderHour ?? 22
        dailyReminderMinute = model?.dailyReminderMinute ?? 0
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

    /// 켜는 경우 권한을 요청하고, 승인됐을 때만 실제로 켠다. 반환값은 요청한 상태가 실제로
    /// 반영됐는지 여부 — 켜려다 거부당하면 false(호출부가 안내 토스트를 띄우는 데 사용).
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

    /// iOS 설정 앱에서 권한을 꺼도 저장된 설정값은 그대로 두고(사용자가 다시 켜면 그대로 복원),
    /// 화면에 보이는 상태만 실제 권한을 반영해 거짓으로 "켜짐"을 보여주지 않게 한다.
    func reconcilePermission() async {
        guard dailyReminderEnabled else { return }
        let status = await notificationScheduler.currentAuthorizationStatus()
        if status != .authorized {
            dailyReminderEnabled = false
        }
    }

    private static func formatReminderTime(hour: Int, minute: Int) -> String {
        let period = hour < 12 ? "오전" : "오후"
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%@ %d:%02d", period, displayHour, minute)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/SettingsViewModelTests`
Expected: PASS — all `SettingsViewModelTests` cases green, including the 6 new ones.

- [ ] **Step 5: Commit**

```bash
git add WadeMoney/Screens/Settings/SettingsViewModel.swift WadeMoneyTests/SettingsViewModelTests.swift
git commit -m "feat(notifications): add daily reminder state to SettingsViewModel"
```

---

### Task 4: `NotificationTimeSheet`

**Files:**
- Create: `WadeMoney/Screens/Settings/NotificationTimeSheet.swift`

**Interfaces:**
- Produces: `NotificationTimeSheet` (`init(hour: Int, minute: Int, onSave: @escaping (Int, Int) -> Void)`).

This task has no automated test — it is pure SwiftUI, same category as `MonthStartDaySheet`. Verified visually in Task 5's manual check (it's only reachable from the Settings screen wired up there).

- [ ] **Step 1: Create the sheet**

Create `WadeMoney/Screens/Settings/NotificationTimeSheet.swift`:

```swift
import SwiftUI

struct NotificationTimeSheet: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTime: Date
    let onSave: (Int, Int) -> Void

    init(hour: Int, minute: Int, onSave: @escaping (Int, Int) -> Void) {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        _selectedTime = State(initialValue: Calendar.current.date(from: comps) ?? Date())
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("알림 시각").font(WadeFont.pretendard(20, weight: .heavy))
                Spacer()
                Button { dismiss() } label: {
                    Icon("close", size: 20).foregroundStyle(WadeColors.ink2(scheme))
                }.buttonStyle(.plain)
            }

            Text("매일 이 시각에 지출 기록 알림을 보내드려요").font(WadeFont.pretendard(12.5)).foregroundStyle(WadeColors.ink3(scheme))

            DatePicker("알림 시각", selection: $selectedTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()

            Button {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
                onSave(comps.hour ?? 22, comps.minute ?? 0)
                dismiss()
            } label: {
                Text("저장").font(WadeFont.pretendard(17, weight: .heavy))
                    .foregroundStyle(WadeColors.onPrimary(scheme))
                    .frame(maxWidth: .infinity).padding(17)
                    .background(WadeColors.primary(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.button, style: .continuous))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, WadeSpacing.screenH)
        .padding(.top, WadeSpacing.sheetTop)
        .padding(.bottom, WadeSpacing.sheetBottom)
        .presentationDetents([.medium])
        .background(WadeColors.sheet(scheme))
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

Run: `xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add WadeMoney/Screens/Settings/NotificationTimeSheet.swift
git commit -m "feat(notifications): add NotificationTimeSheet"
```

---

### Task 5: Wire the "알림" section into `SettingsScreen`

**Files:**
- Modify: `WadeMoney/Screens/Settings/SettingsScreen.swift`

**Interfaces:**
- Consumes: `SettingsViewModel.dailyReminderEnabled/.dailyReminderHour/.dailyReminderMinute/.dailyReminderTimeText/.setDailyReminderEnabled(_:)/.setDailyReminderTime(hour:minute:)/.reconcilePermission()` (Task 3); `NotificationTimeSheet` (Task 4).

This task has no automated test — pure SwiftUI wiring plus a toast side effect already covered by the existing `showSettingsToast` mechanism. Verified in Step 4 via simulator screenshots.

- [ ] **Step 1: Add the sheet case**

In `WadeMoney/Screens/Settings/SettingsScreen.swift`, replace the `SettingsSheet` enum (lines 17-31):

```swift
    private enum SettingsSheet: Identifiable {
        case budget
        case monthStartDay
        case notificationTime
        case share(URL)
        case feedbackMail

        var id: String {
            switch self {
            case .budget: return "budget"
            case .monthStartDay: return "monthStartDay"
            case .notificationTime: return "notificationTime"
            case .share(let url): return "share-\(url.absoluteString)"
            case .feedbackMail: return "feedbackMail"
            }
        }
    }
```

- [ ] **Step 2: Add the "알림" section and reconcile-on-appear**

Insert a new section right after the "동기화 · 데이터" section (currently lines 59-63):

```swift
                            section("동기화 · 데이터") {
                                syncStatusRow()
                                backupCheckRow()
                                row(icon: "ios_share", tint: WadeColors.ink2(scheme), label: "CSV 내보내기", trailing: nil) { exportCSV() }
                            }
                            section("알림") {
                                dailyReminderToggleRow(vm)
                                if vm.dailyReminderEnabled {
                                    dailyReminderTimeRow(vm)
                                }
                            }
```

Then update the `.onAppear` block (currently lines 117-125) to also kick off the async permission reconciliation:

```swift
        .onAppear {
            if viewModel == nil {
                let ctx = modelContext
                let vm = SettingsViewModel(settingsStore: SettingsStore(context: ctx),
                                           categoryStore: CategoryStore(context: ctx),
                                           now: Date(), calendar: .current)
                vm.load(); viewModel = vm
                Task { await vm.reconcilePermission() }
            }
        }
```

- [ ] **Step 3: Add the sheet case and the two new row helpers**

In `sheetContent(_:)` (currently lines 143-157), add a case:

```swift
    @ViewBuilder private func sheetContent(_ sheet: SettingsSheet) -> some View {
        switch sheet {
        case .budget:
            BudgetSheet(current: viewModel?.budget ?? 0) { amount in viewModel?.setBudget(amount) }
        case .monthStartDay:
            MonthStartDaySheet(current: viewModel?.monthStartDay ?? 1) { day in viewModel?.setMonthStartDay(day) }
        case .notificationTime:
            NotificationTimeSheet(
                hour: viewModel?.dailyReminderHour ?? 22,
                minute: viewModel?.dailyReminderMinute ?? 0
            ) { hour, minute in
                viewModel?.setDailyReminderTime(hour: hour, minute: minute)
            }
        case .share(let url):
            ActivityView(url: url)
        case .feedbackMail:
            MailComposeView(draft: makeFeedbackDraft()) {
                presentedSheet = nil
            }
            .ignoresSafeArea()
        }
    }
```

Add the two new row helpers after `aiToggleRow(_:)` (end of the file, currently lines 329-341, right after its closing `}` before the struct's final `}`):

```swift
    private func dailyReminderToggleRow(_ vm: SettingsViewModel) -> some View {
        HStack(spacing: 13) {
            Icon("notifications", size: 20).foregroundStyle(WadeColors.primary(scheme)).frame(width: 36, height: 36)
                .background(WadeColors.primarysoft(scheme), in: RoundedRectangle(cornerRadius: 10))
            Text("오늘 지출 알림").font(WadeFont.pretendard(15, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
            Spacer()
            Toggle("", isOn: Binding(
                get: { vm.dailyReminderEnabled },
                set: { newValue in
                    Task {
                        let succeeded = await vm.setDailyReminderEnabled(newValue)
                        if newValue && !succeeded {
                            showSettingsToast("iOS 설정에서 알림 권한을 허용해주세요")
                        }
                    }
                }
            )).labelsHidden().tint(WadeColors.primary(scheme))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func dailyReminderTimeRow(_ vm: SettingsViewModel) -> some View {
        row(icon: "schedule", tint: WadeColors.ink2(scheme), label: "알림 시각", trailing: vm.dailyReminderTimeText) {
            presentedSheet = .notificationTime
        }
    }
```

- [ ] **Step 4: Build, then manually verify on a signed simulator**

Run: `xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: BUILD SUCCEEDED.

Then, on the simulator. Notification authorization is not a `simctl privacy` service (that command only covers calendar/contacts/location/photos/media-library/microphone/motion/reminders/siri — verified via `xcrun simctl privacy` with no arguments) — resetting it requires uninstalling the app so the next launch is a clean permission state:

```bash
xcrun simctl uninstall "iPhone 17e" com.kimhyeongi.WadeMoney
```

- Reinstall/reopen the app, toggle "오늘 지출 알림" on → system permission dialog appears → tap Allow → toggle stays on, "알림 시각" row appears showing "오후 10:00" (default).
- Tap "알림 시각" → wheel picker sheet opens → change time → 저장 → row now shows the new time.
- To test the deny path, uninstall again (`xcrun simctl uninstall ...`), reinstall, toggle on, and tap Don't Allow this time → toggle stays off, toast "iOS 설정에서 알림 권한을 허용해주세요" appears.
- To test `reconcilePermission`'s revoke-detection: after granting once and turning the toggle on, go to the Simulator's Settings app → Notifications → WadeMoney → turn off "Allow Notifications" there, then relaunch WadeMoney and open its Settings screen — the toggle should now show off even though it was left on before, since the OS permission was revoked externally.

Take screenshots of each state (reuse this session's established pattern: temporary XCUITest navigation + `xcrun simctl io ... screenshot`, then revert the temporary test).

- [ ] **Step 5: Commit**

```bash
git add WadeMoney/Screens/Settings/SettingsScreen.swift
git commit -m "feat(settings): add daily expense reminder section"
```

---

## Final Verification

- [ ] Run the full unit test suite: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests`. Expected: all green (existing + the 8 new cases from Tasks 1 and 3).
- [ ] Run the existing UI regression suite: `xcodebuild test -scheme WadeMoneyUITests -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyUITests/CoreFlowUITests`. Expected: all pass (confirms the new Settings section didn't break existing navigation/back-swipe/tab flows).
- [ ] On a signed simulator with permission granted and a reminder scheduled for a time a couple of minutes away, background the app and wait for the banner to confirm real end-to-end delivery at least once.
- [ ] Confirm `git diff` against `main` touches no files under `docs/design/app-design-specification-analysis/`.
