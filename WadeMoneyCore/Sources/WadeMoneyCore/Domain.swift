import Foundation

public enum TransactionType: Sendable, Equatable {
    case expense
    case income
}

public struct TransactionRecord: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var amount: Decimal
    public var type: TransactionType
    public var categoryID: UUID?
    public var memo: String?
    public var date: Date
    public var createdAt: Date
    public var isExcludedFromBudget: Bool

    public init(
        id: UUID = UUID(),
        amount: Decimal,
        type: TransactionType = .expense,
        categoryID: UUID? = nil,
        memo: String? = nil,
        date: Date,
        createdAt: Date = .init(timeIntervalSince1970: 0),
        isExcludedFromBudget: Bool = false
    ) {
        self.id = id
        self.amount = amount
        self.type = type
        self.categoryID = categoryID
        self.memo = memo
        self.date = date
        self.createdAt = createdAt
        self.isExcludedFromBudget = isExcludedFromBudget
    }
}

public struct CategoryRef: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var iconName: String
    public var colorHex: String
    public var sortOrder: Int
    public var isArchived: Bool

    public init(
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

public struct EngineSettings: Sendable, Equatable {
    public var monthStartDay: Int
    public var aiEnabled: Bool

    public init(monthStartDay: Int = 1, aiEnabled: Bool = true) {
        self.monthStartDay = monthStartDay
        self.aiEnabled = aiEnabled
    }
}
