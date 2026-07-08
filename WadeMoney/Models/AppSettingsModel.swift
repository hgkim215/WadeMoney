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
