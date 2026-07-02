import Foundation
import SwiftData
import WadeMoneyCore

@MainActor
final class SettingsStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func settingsModel() throws -> AppSettingsModel {
        if let existing = try context.fetch(FetchDescriptor<AppSettingsModel>()).first {
            return existing
        }
        let created = AppSettingsModel()
        context.insert(created)
        try context.save()
        return created
    }

    func settings() throws -> EngineSettings {
        try settingsModel().toEngineSettings()
    }

    func setMonthlyBudget(_ amount: Decimal, for ym: YearMonth) throws {
        let year = ym.year
        let month = ym.month
        let descriptor = FetchDescriptor<MonthlyBudgetModel>(
            predicate: #Predicate { $0.effectiveYear == year && $0.effectiveMonth == month }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.amount = amount
        } else {
            context.insert(MonthlyBudgetModel(effectiveYear: year, effectiveMonth: month, amount: amount))
        }
        try context.save()
    }

    func budgetBook() throws -> BudgetBook {
        let snapshots = try context.fetch(FetchDescriptor<MonthlyBudgetModel>())
            .map { $0.toSnapshot() }
        return BudgetBook(snapshots)
    }

    func setMonthStartDay(_ day: Int) throws {
        let model = try settingsModel()
        model.monthStartDay = min(max(day, 1), 28)
        try context.save()
    }

    func setAIEnabled(_ enabled: Bool) throws {
        let model = try settingsModel()
        model.aiEnabled = enabled
        try context.save()
    }
}
