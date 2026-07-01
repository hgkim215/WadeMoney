import Foundation
import SwiftData

@Model
final class AppSettingsModel {
    var id: UUID = UUID()
    var monthStartDay: Int = 1
    var aiEnabled: Bool = true

    init(id: UUID = UUID(), monthStartDay: Int = 1, aiEnabled: Bool = true) {
        self.id = id
        self.monthStartDay = monthStartDay
        self.aiEnabled = aiEnabled
    }
}
