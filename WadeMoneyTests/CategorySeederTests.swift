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

extension CategorySeederTests {
    @Test func doesNotReseedWhenFlagAlreadySetEvenIfLocalStoreEmpty() throws {
        let c = try ctx()
        c.insert(AppSettingsModel(didSeedDefaultCategories: true))
        try c.save()
        try CategorySeeder.seedIfNeeded(c)
        let count = try c.fetchCount(FetchDescriptor<CategoryModel>())
        #expect(count == 0)   // 다른 기기가 이미 시드했고 플래그가 먼저 동기화됐다고 가정 — 로컬에서 또 시드하지 않음
    }

    @Test func reconcileMergesDuplicateDefaultsAndRepointsTransactions() throws {
        // 두 기기가 각자 시드한 뒤 CloudKit 병합 → 식비가 2개. 승자(id 최솟값)로 합치고 거래를 재연결.
        let c = try ctx()
        let a = CategoryModel(name: "식비", iconName: "restaurant", colorHex: "#E28A4E", sortOrder: 0)
        let b = CategoryModel(name: "식비", iconName: "restaurant", colorHex: "#E28A4E", sortOrder: 0)
        c.insert(a); c.insert(b)
        c.insert(TransactionModel(amount: 5000, type: .expense, category: b, memo: nil,
                                  date: Date(timeIntervalSince1970: 1_000_000), createdAt: Date(timeIntervalSince1970: 1_000_000)))
        try c.save()

        try CategorySeeder.reconcileDuplicateCategories(c)

        let remaining = try c.fetch(FetchDescriptor<CategoryModel>()).filter { $0.name == "식비" }
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == min(a.id, b.id))
        let txn = try c.fetch(FetchDescriptor<TransactionModel>()).first
        #expect(txn?.category?.id == min(a.id, b.id))   // 거래가 승자 카테고리로 이동
        _ = try #require(txn)
    }

    @Test func reconcileMergesDuplicateCustomCategoriesToo() throws {
        // 커스텀 카테고리도 이름이 같으면 병합 대상이다 (기본 카테고리만 다루던 이전 동작을 일반화).
        let c = try ctx()
        try CategorySeeder.seedIfNeeded(c)   // 기본 8종(중복 없음)
        c.insert(CategoryModel(name: "구독", iconName: "category", colorHex: "#000000", sortOrder: 8))
        c.insert(CategoryModel(name: "구독", iconName: "category", colorHex: "#000000", sortOrder: 9))
        try c.save()

        try CategorySeeder.reconcileDuplicateCategories(c)

        let remaining = try c.fetch(FetchDescriptor<CategoryModel>()).filter { $0.name == "구독" }
        #expect(remaining.count == 1)
        #expect(try c.fetchCount(FetchDescriptor<CategoryModel>()) == 9)   // 기본 8 + 구독 1(병합됨)
    }

    @Test func reconcileDoesNotMergeVisuallyDistinctCategoriesWithSameName() throws {
        // "카페"를 "식비"로 리네임하면 이름만 겹치는 별개 카테고리가 생긴다 —
        // 진짜 CloudKit 중복(이름+아이콘+색상까지 동일)만 병합하고 이런 경우는 둘 다 남겨야 한다.
        let c = try ctx()
        c.insert(CategoryModel(name: "식비", iconName: "restaurant", colorHex: "#E28A4E", sortOrder: 0))
        c.insert(CategoryModel(name: "식비", iconName: "local_cafe", colorHex: "#C4924E", sortOrder: 1))
        try c.save()

        try CategorySeeder.reconcileDuplicateCategories(c)

        let remaining = try c.fetch(FetchDescriptor<CategoryModel>()).filter { $0.name == "식비" }
        #expect(remaining.count == 2)
    }

    @Test func backfillsFlagWhenCategoriesAlreadyExistWithoutFlag() throws {
        let c = try ctx()
        c.insert(CategoryModel(name: "커스텀", iconName: "category", colorHex: "#000000", sortOrder: 0))
        try c.save()
        try CategorySeeder.seedIfNeeded(c)
        let count = try c.fetchCount(FetchDescriptor<CategoryModel>())
        #expect(count == 1)   // 기존 카테고리 위에 기본 8종을 추가로 시드하지 않음(구버전 사용자 마이그레이션 케이스)
        let settings = try c.fetch(FetchDescriptor<AppSettingsModel>()).first
        #expect(settings?.didSeedDefaultCategories == true)
    }
}
