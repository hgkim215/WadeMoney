import Foundation
import WadeMoneyCore

enum KindMapping {
    static func core(_ k: TransactionKind) -> TransactionType {
        switch k {
        case .expense: return .expense
        case .income: return .income
        }
    }
    static func model(_ t: TransactionType) -> TransactionKind {
        switch t {
        case .expense: return .expense
        case .income: return .income
        }
    }
}

extension TransactionModel {
    func toRecord() -> TransactionRecord {
        TransactionRecord(
            id: id,
            amount: amount,
            type: KindMapping.core(type),
            categoryID: category?.id,
            memo: memo,
            date: date,
            createdAt: createdAt
        )
    }
}

extension CategoryModel {
    func toRef() -> CategoryRef {
        CategoryRef(
            id: id,
            name: name,
            iconName: iconName,
            colorHex: colorHex,
            sortOrder: sortOrder,
            isArchived: isArchived
        )
    }
}

extension MonthlyBudgetModel {
    func toSnapshot() -> BudgetSnapshot {
        BudgetSnapshot(
            effectiveMonth: YearMonth(year: effectiveYear, month: effectiveMonth),
            amount: amount
        )
    }
}

extension AppSettingsModel {
    func toEngineSettings() -> EngineSettings {
        EngineSettings(monthStartDay: monthStartDay, aiEnabled: aiEnabled)
    }
}
