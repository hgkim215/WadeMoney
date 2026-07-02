import Foundation
import SwiftData

@Model
final class AppSettingsModel {
    var id: UUID = UUID()
    var monthStartDay: Int = 1
    var aiEnabled: Bool = true
    var didSeedDefaultCategories: Bool = false

    init(
        id: UUID = UUID(),
        monthStartDay: Int = 1,
        aiEnabled: Bool = true,
        didSeedDefaultCategories: Bool = false
    ) {
        self.id = id
        self.monthStartDay = monthStartDay
        self.aiEnabled = aiEnabled
        self.didSeedDefaultCategories = didSeedDefaultCategories
    }
}
