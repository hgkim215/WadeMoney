import Foundation
import SwiftData
import Testing
@testable import WadeMoney

@MainActor
struct CategoryStoreTests {
    func store() throws -> (CategoryStore, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        return (CategoryStore(context: container.mainContext), container)
    }

    @Test func addAppendsWithNextSortOrder() throws {
        let (s, c) = try store()
        let before = try s.active()
        try s.add(name: "여행", iconName: "flight", colorHex: "#4DA0C4")
        let after = try s.active()
        #expect(after.count == before.count + 1)
        let added = try #require(after.first { $0.name == "여행" })
        #expect(added.sortOrder == before.map(\.sortOrder).max()! + 1)
        _ = c
    }

    @Test func archiveAndRestoreMovesBetweenLists() throws {
        let (s, c) = try store()
        let cafe = try s.active().first { $0.name == "카페" }!.id
        try s.archive(id: cafe)
        #expect(try s.active().contains { $0.id == cafe } == false)
        #expect(try s.archived().contains { $0.id == cafe } == true)
        try s.restore(id: cafe)
        #expect(try s.active().contains { $0.id == cafe } == true)
        _ = c
    }

    @Test func updateChangesNameIconColor() throws {
        let (s, c) = try store()
        let etc = try s.active().first { $0.name == "기타" }!.id
        try s.update(id: etc, name: "기타지출", iconName: "more_horiz", colorHex: "#999999")
        let updated = try #require(try s.active().first { $0.id == etc })
        #expect(updated.name == "기타지출")
        #expect(updated.iconName == "more_horiz")
        #expect(updated.colorHex == "#999999")
        _ = c
    }

    @Test func reorderReassignsSortOrder() throws {
        let (s, c) = try store()
        let ids = try s.active().map(\.id)
        let reversed = Array(ids.reversed())
        try s.reorder(reversed)
        #expect(try s.active().map(\.id) == reversed)
        _ = c
    }
}
