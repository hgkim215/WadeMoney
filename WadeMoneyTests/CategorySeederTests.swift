import Foundation
import SwiftData
import Testing
@testable import WadeMoney

@MainActor
struct CategorySeederTests {
    // 컨테이너를 보관해야 한다: 로컬 표현식에서 container를 바인딩하지 않고
    // `.mainContext`만 반환하면 인메모리 컨테이너가 즉시 해제되어
    // 이후 context 사용 시 크래시가 난다.
    let container: ModelContainer

    init() throws {
        container = try PersistenceController.makeInMemoryContainer()
    }

    func ctx() throws -> ModelContext {
        container.mainContext
    }

    @Test func seedsEightDefaultsOnEmptyStore() throws {
        let c = try ctx()
        try CategorySeeder.seedIfNeeded(c)
        let cats = try c.fetch(FetchDescriptor<CategoryModel>())
        #expect(cats.count == 8)
        #expect(Set(cats.map(\.name)) == ["식비", "카페", "교통", "쇼핑", "문화", "의료", "주거", "기타"])
        // 순서(sortOrder)가 0..7로 배정됨
        #expect(Set(cats.map(\.sortOrder)) == Set(0...7))
    }

    @Test func seedingIsIdempotent() throws {
        let c = try ctx()
        try CategorySeeder.seedIfNeeded(c)
        try CategorySeeder.seedIfNeeded(c)
        let count = try c.fetchCount(FetchDescriptor<CategoryModel>())
        #expect(count == 8)
    }

    @Test func firstCategoryMatchesDesignSpec() throws {
        let c = try ctx()
        try CategorySeeder.seedIfNeeded(c)
        let food = try c.fetch(FetchDescriptor<CategoryModel>())
            .first { $0.name == "식비" }
        #expect(food?.iconName == "restaurant")
        #expect(food?.colorHex == "#E28A4E")
    }
}
