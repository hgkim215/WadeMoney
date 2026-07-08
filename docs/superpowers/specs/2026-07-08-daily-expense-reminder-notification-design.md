# Daily Expense Reminder Notification — Design

## Problem

The app has no way to nudge users who forget to log spending. Users have to remember on their own to open the app and record today's expenses. There is currently no local-notification infrastructure at all (greenfield — no `UNUserNotificationCenter` usage anywhere in the codebase). The existing `aps-environment`/`UIBackgroundModes: remote-notification` entitlements exist only for CloudKit's silent sync push and are unrelated to this feature.

## Non-Goals

- No "smart" skip-if-already-logged-today logic — the notification fires unconditionally at the configured time every day, regardless of whether the user already recorded an expense. (Confirmed: simplest `UNCalendarNotificationTrigger(repeats: true)` — no background refresh or notification service extension needed.)
- No onboarding/first-launch tour in this spec — a multi-page onboarding tour that ends by prompting for notification permission is a separate, larger feature to be brainstormed and built afterward. This spec builds the notification system as a standalone feature reachable from Settings only.
- No foreground notification banner delegate setup — default iOS behavior (banner shown only when the app is backgrounded/not running) is sufficient for this scope.
- No cross-device "force resync" of the schedule — each device independently (re)schedules its own local `UNNotificationRequest` based on the synced `AppSettingsModel` values; CloudKit only syncs the *setting*, not the OS-level scheduled notification itself.

## 1. Storage — `AppSettingsModel` extension

Add three fields, following the existing `monthStartDay`/`aiEnabled` pattern (synced via CloudKit like the rest of `AppSettingsModel`):

```swift
var dailyReminderEnabled: Bool = false
var dailyReminderHour: Int = 22      // default 22:00 (오후 10시)
var dailyReminderMinute: Int = 0
```

`SettingsStore` gets a new method:

```swift
func setDailyReminder(enabled: Bool, hour: Int, minute: Int) throws {
    let model = try settingsModel()
    model.dailyReminderEnabled = enabled
    model.dailyReminderHour = min(max(hour, 0), 23)
    model.dailyReminderMinute = min(max(minute, 0), 59)
    try context.save()
}
```

## 2. Notification engine — `DailyReminderScheduler` (new, no UI)

A stateless enum (mirrors `WidgetPersistence`'s style — no stored state, pure functions over `UNUserNotificationCenter.current()`):

- `static func requestAuthorization() async -> Bool` — calls `requestAuthorization(options: [.alert, .sound])`, returns whether granted.
- `static func currentAuthorizationStatus() async -> UNAuthorizationStatus` — reads `getNotificationSettings().authorizationStatus`. Used to detect if the user revoked permission from iOS Settings after previously granting it, so the app's own toggle state doesn't silently lie.
- `static func schedule(hour: Int, minute: Int)` — builds `UNMutableNotificationContent` (title "오늘 지출 기록했나요?", body "잊기 전에 오늘 쓴 돈을 기록해보세요") and a `UNCalendarNotificationTrigger` with `dateComponents.hour`/`.minute` set and `repeats: true`, then calls `add(_:)` with a fixed identifier `"daily-expense-reminder"`. Adding with the same identifier again (e.g. when the user changes the time) implicitly replaces the previous pending request — no separate cancel-then-add needed, but `cancel()` still exists for the toggle-off path.
- `static func cancel()` — `removePendingNotificationRequests(withIdentifiers: ["daily-expense-reminder"])`.

Because `repeats: true` calendar-trigger notifications persist at the OS level independent of the app process, the app only needs to call `schedule`/`cancel` when the user actually changes the setting — not on every launch. On launch/Settings-screen-appear, the app calls `currentAuthorizationStatus()` and reconciles: if the stored `dailyReminderEnabled == true` but the OS status is no longer `.authorized`, the Settings screen reflects the toggle as off (without silently rewriting `AppSettingsModel` — the stored preference stays as the user last set it, only the displayed/effective state accounts for the revoked permission, same "distrust cached assumption, verify real system state" principle used for `CloudSyncMonitor`).

## 3. Settings screen

New section "알림" (placed after "동기화 · 데이터"):

- **Toggle row** "오늘 지출 알림" (`Toggle`, mirrors `aiToggleRow`'s structure). Turning it **on**:
  1. Calls `DailyReminderScheduler.requestAuthorization()`.
  2. If granted: `SettingsStore.setDailyReminder(enabled: true, hour:, minute:)` with the currently stored hour/minute (defaults 22:00 on first-ever enable), then `DailyReminderScheduler.schedule(hour:minute:)`.
  3. If denied: toggle stays off, `settingsToast` shows "iOS 설정에서 알림 권한을 허용해주세요" (reuses the existing toast mechanism).
  Turning it **off**: `setDailyReminder(enabled: false, ...)` + `DailyReminderScheduler.cancel()`.
- **Time row** "알림 시각" — only rendered when the toggle is on. Trailing text shows the formatted time (e.g. "오후 10:00"). Tapping opens `NotificationTimeSheet`.

### `NotificationTimeSheet` (new)

Same shape as `MonthStartDaySheet.swift`: title, one-line description, wheel picker, "저장" button, `.presentationDetents([.medium])`. The picker uses a `DatePicker(selection:, displayedComponents: .hourAndMinute)` in `.wheel` style bound to a `Date` constructed from the current hour/minute (date components themselves are irrelevant — only hour/minute are read back out on save). On save: `SettingsStore.setDailyReminder(enabled: true, hour:, minute:)` + `DailyReminderScheduler.schedule(hour:minute:)`.

## Files (expected)

- `WadeMoney/Models/AppSettingsModel.swift` — add 3 fields.
- `WadeMoney/Stores/SettingsStore.swift` — add `setDailyReminder(enabled:hour:minute:)`.
- `WadeMoney/Notifications/DailyReminderScheduler.swift` (new).
- `WadeMoney/Screens/Settings/SettingsViewModel.swift` — expose `dailyReminderEnabled`, `dailyReminderTimeText`, `toggleDailyReminder()` (async), `setDailyReminderTime(hour:minute:)`; reconcile against `DailyReminderScheduler.currentAuthorizationStatus()` on `load()`.
- `WadeMoney/Screens/Settings/NotificationTimeSheet.swift` (new).
- `WadeMoney/Screens/Settings/SettingsScreen.swift` — new "알림" section, sheet case.
- Tests: `WadeMoneyTests/SettingsStoreTests.swift` (new `setDailyReminder` case), `WadeMoneyTests/SettingsViewModelTests.swift` (toggle/time text formatting — with `DailyReminderScheduler`'s actual `UNUserNotificationCenter` calls needing to be exercised through a thin protocol seam so tests don't require real OS permission prompts in CI).

## Verification

- `SettingsStore.setDailyReminder` covered by a direct unit test (value clamping, persistence) — same pattern as `setMonthStartDay`.
- `DailyReminderScheduler`'s scheduling logic can't be fully unit-tested against the real `UNUserNotificationCenter` in a CI/simulator context without a signed, permission-granted run — the plan's implementation phase should introduce a small protocol (e.g. `NotificationScheduling`) that `DailyReminderScheduler` conforms to, so `SettingsViewModel`'s toggle/time-change logic can be unit-tested against a fake, while the real `UNUserNotificationCenter`-backed implementation is verified manually on a signed simulator/device (grant permission, toggle on, background the app, wait for the scheduled time or use a near-future test time, confirm the banner appears).
- Settings UI (toggle, time row visibility, sheet) verified via simulator screenshots for both permission-granted and permission-denied paths, plus the toast on denial.
