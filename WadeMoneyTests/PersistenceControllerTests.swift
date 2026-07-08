import Foundation
import SwiftData
import Testing
@testable import WadeMoney

@MainActor
struct PersistenceControllerTests {
    @Test func inMemoryContainerInsertsAndFetches() throws {
        let container = try PersistenceController.makeInMemoryContainer()
        let ctx = container.mainContext
        ctx.insert(AppSettingsModel(monthStartDay: 1))
        try ctx.save()
        let count = try ctx.fetchCount(FetchDescriptor<AppSettingsModel>())
        #expect(count == 1)
    }

    @Test func schemaCoversAllModels() {
        // 스키마에 4개 엔티티가 모두 등록됐는지 확인.
        let names = Set(PersistenceController.sharedSchema.entities.map(\.name))
        #expect(names.isSuperset(of: ["CategoryModel", "TransactionModel", "MonthlyBudgetModel", "AppSettingsModel"]))
    }

    @Test func makeAppContainerSucceedsWithoutThrowing() throws {
        // cloudKitEnabled 값은 실행 환경(App Group 프로비저닝·서명 여부)에 따라 달라진다 —
        // 이 머신은 실제 개발팀 서명이 구성돼 있어 App Group이 항상 사용 가능하므로 특정
        // 값을 단언하지 않는다. App Group이 사용 가능한 환경에서는 실제 앱이 쓰는 온디스크
        // 공유 저장소가 반환되므로, 여기서 데이터를 쓰면 그 저장소를 오염시킨다 — 그래서
        // 쓰기 없이 컨테이너가 예외 없이 만들어지는지만 확인한다.
        _ = try PersistenceController.makeAppContainer()
    }
}
