import Foundation
import UserNotifications

/// SettingsViewModel이 실제 UNUserNotificationCenter 대신 주입해 테스트할 수 있도록 하는 얇은 시임.
protocol NotificationScheduling {
    func requestAuthorization() async -> Bool
    func currentAuthorizationStatus() async -> UNAuthorizationStatus
    func schedule(hour: Int, minute: Int)
    func cancel()
}

/// 매일 지정 시각에 "오늘 지출 기록했나요?" 알림을 반복 예약하는 실제 구현.
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

        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }
}
