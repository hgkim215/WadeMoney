import Foundation
import SwiftData

@Model
final class CategoryModel {
    var id: UUID = UUID()
    var name: String = ""
    var iconName: String = "category"
    var colorHex: String = "#A69B8C"
    var sortOrder: Int = 0
    var isArchived: Bool = false

    // CloudKit 요구: to-many 관계는 옵셔널.
    @Relationship(deleteRule: .nullify, inverse: \TransactionModel.category)
    var transactions: [TransactionModel]?

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String,
        colorHex: String,
        sortOrder: Int,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.isArchived = isArchived
    }
}
