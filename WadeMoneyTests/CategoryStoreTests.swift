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

    // MARK: - 이름 중복 방지

    @Test func addRejectsDuplicateName() throws {
        let (s, c) = try store()
        let before = try s.active().count
        #expect(throws: (any Error).self) {
            try s.add(name: "카페", iconName: "flight", colorHex: "#4DA0C4")
        }
        #expect(try s.active().count == before)
        _ = c
    }

    @Test func addRejectsDuplicateNameIgnoringWhitespace() throws {
        let (s, c) = try store()
        #expect(throws: (any Error).self) {
            try s.add(name: " 카페 ", iconName: "flight", colorHex: "#4DA0C4")
        }
        _ = c
    }

    @Test func addRejectsNameMatchingArchivedCategory() throws {
        let (s, c) = try store()
        let cafe = try s.active().first { $0.name == "카페" }!.id
        try s.archive(id: cafe)
        #expect(throws: (any Error).self) {
            try s.add(name: "카페", iconName: "flight", colorHex: "#4DA0C4")
        }
        _ = c
    }

    @Test func updateRejectsRenamingToExistingName() throws {
        let (s, c) = try store()
        let cafe = try s.active().first { $0.name == "카페" }!.id
        #expect(throws: (any Error).self) {
            try s.update(id: cafe, name: "식비", iconName: "local_cafe", colorHex: "#C4924E")
        }
        #expect(try s.active().contains { $0.name == "카페" })
        _ = c
    }

    @Test func updateAllowsKeepingOwnName() throws {
        let (s, c) = try store()
        let cafe = try s.active().first { $0.name == "카페" }!.id
        try s.update(id: cafe, name: "카페", iconName: "savings", colorHex: "#7BB661")
        let updated = try #require(try s.active().first { $0.id == cafe })
        #expect(updated.iconName == "savings")
        _ = c
    }

    @Test func isNameTakenChecksTrimmedNameAcrossActiveAndArchived() throws {
        let (s, c) = try store()
        let cafe = try s.active().first { $0.name == "카페" }!.id
        #expect(s.isNameTaken("카페"))
        #expect(s.isNameTaken(" 카페 "))
        #expect(!s.isNameTaken("여행"))
        #expect(!s.isNameTaken("카페", excluding: cafe))   // 자기 자신 이름 유지 허용
        try s.archive(id: cafe)
        #expect(s.isNameTaken("카페"))                      // 보관된 카테고리와도 중복 금지
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
