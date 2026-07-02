import Foundation
import SwiftData
import WidgetKit
import WadeMoneyCore

@MainActor
final class SettingsStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// CloudKit 동기화로 기기마다 만든 설정 행이 중복될 수 있다. id 최솟값 행을 결정적으로 채택해
    /// 모든 기기가 같은 행을 읽고 쓰게 하고, 나머지는 플래그를 합친 뒤 제거한다.
    func settingsModel() throws -> AppSettingsModel {
        let all = try context.fetch(FetchDescriptor<AppSettingsModel>())
        if let winner = all.min(by: { $0.id < $1.id }) {
            let losers = all.filter { $0.id != winner.id }
            if !losers.isEmpty {
                // 시드 완료 플래그는 어느 행에 있었든 유지해야 재시드를 막는다.
                winner.didSeedDefaultCategories = winner.didSeedDefaultCategories
                    || losers.contains { $0.didSeedDefaultCategories }
                losers.forEach(context.delete)
                try context.save()
            }
            return winner
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
        // 같은 달 행이 CloudKit 동기화로 중복될 수 있다 — 결정적(id 최솟값) 행에 쓰고 나머지는 치유 삭제.
        let rows = try context.fetch(descriptor).sorted { $0.id < $1.id }
        if let keeper = rows.first {
            keeper.amount = amount
            rows.dropFirst().forEach(context.delete)
        } else {
            context.insert(MonthlyBudgetModel(effectiveYear: year, effectiveMonth: month, amount: amount))
        }
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func budgetBook() throws -> BudgetBook {
        // 같은 달 중복 행이 있으면 id 최솟값 행만 반영해 기기 간 표시가 일치하도록 한다.
        let models = try context.fetch(FetchDescriptor<MonthlyBudgetModel>()).sorted { $0.id < $1.id }
        var seenMonths = Set<Int>()
        var snapshots: [BudgetSnapshot] = []
        for model in models {
            let key = model.effectiveYear * 100 + model.effectiveMonth
            guard seenMonths.insert(key).inserted else { continue }
            snapshots.append(model.toSnapshot())
        }
        return BudgetBook(snapshots)
    }

    func setMonthStartDay(_ day: Int) throws {
        let model = try settingsModel()
        model.monthStartDay = min(max(day, 1), 28)
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func setAIEnabled(_ enabled: Bool) throws {
        let model = try settingsModel()
        model.aiEnabled = enabled
        try context.save()
    }
}
