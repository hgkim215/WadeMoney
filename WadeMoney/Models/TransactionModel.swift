import Foundation
import SwiftData

enum TransactionKind: String, Sendable {
    case expense
    case income
}

@Model
final class TransactionModel {
    var id: UUID = UUID()
    var amount: Decimal = 0
    /// 원시 저장값. `type`으로 접근할 것.
    var typeRaw: String = TransactionKind.expense.rawValue
    @Relationship(deleteRule: .nullify)
    var category: CategoryModel?
    var memo: String?
    var date: Date = Date(timeIntervalSince1970: 0)
    var createdAt: Date = Date(timeIntervalSince1970: 0)
    var isExcludedFromBudget: Bool = false

    var type: TransactionKind {
        get { TransactionKind(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        amount: Decimal,
        type: TransactionKind = .expense,
        category: CategoryModel?,
        memo: String?,
        date: Date,
        createdAt: Date = Date(timeIntervalSince1970: 0),
        isExcludedFromBudget: Bool = false
    ) {
        self.id = id
        self.amount = amount
        self.typeRaw = type.rawValue
        self.category = category
        self.memo = memo
        self.date = date
        self.createdAt = createdAt
        self.isExcludedFromBudget = isExcludedFromBudget
    }
}
