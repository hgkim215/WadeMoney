import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct SettingsViewModelTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }
    func vm() throws -> (SettingsViewModel, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        let ctx = container.mainContext
        let vm = SettingsViewModel(settingsStore: SettingsStore(context: ctx),
                                   categoryStore: CategoryStore(context: ctx),
                                   now: date(2026, 7, 15), calendar: utc)
        return (vm, container)
    }

    @Test func loadsBudgetAndCategoryCount() throws {
        let (vm, c) = try vm()
        vm.setBudget(1_300_000)
        vm.load()
        #expect(vm.budgetText == "1,300,000")
        #expect(vm.categoryCountText == "8개")
        _ = c
    }

    @Test func toggleAIPersists() throws {
        let (vm, c) = try vm()
        vm.load()
        let initial = vm.aiEnabled
        vm.toggleAI()
        #expect(vm.aiEnabled == !initial)
        // reload reflects persisted value
        vm.load()
        #expect(vm.aiEnabled == !initial)
        _ = c
    }
}
