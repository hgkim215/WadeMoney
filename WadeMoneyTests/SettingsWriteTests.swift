import Foundation
import Testing
import SwiftData
@testable import WadeMoney

@MainActor
struct SettingsWriteTests {
    func store() throws -> (SettingsStore, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        return (SettingsStore(context: container.mainContext), container)
    }

    @Test func setMonthStartDayClampsAndPersists() throws {
        let (s, c) = try store()
        try s.setMonthStartDay(25)
        #expect(try s.settings().monthStartDay == 25)
        try s.setMonthStartDay(99)   // 28로 클램프
        #expect(try s.settings().monthStartDay == 28)
        try s.setMonthStartDay(0)    // 1로 클램프
        #expect(try s.settings().monthStartDay == 1)
        _ = c
    }

    @Test func setAIEnabledPersists() throws {
        let (s, c) = try store()
        try s.setAIEnabled(false)
        #expect(try s.settings().aiEnabled == false)
        _ = c
    }
}
