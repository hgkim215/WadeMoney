import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct QuickAddPolishTests {
    func repoWithSettings(aiEnabled: Bool) throws -> (LedgerRepository, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        let ctx = container.mainContext
        try CategorySeeder.seedIfNeeded(ctx)
        try SettingsStore(context: ctx).setAIEnabled(aiEnabled)
        return (LedgerRepository(context: ctx), container)
    }
    func catID(_ repo: LedgerRepository, _ name: String) throws -> UUID {
        try repo.allCategories(includeArchived: false).first { $0.name == name }!.id
    }

    @Test func polishUpdatesMemoAndSuggestsCategory() async throws {
        let (repo, container) = try repoWithSettings(aiEnabled: true)
        let cafe = try catID(repo, "카페")
        let vm = QuickAddViewModel(repository: repo,
                                    aiAvailability: FakeAIAvailability(isAvailable: true),
                                    memoPolisher: FakeMemoPolisher(result: .success(MemoPolishResult(polishedMemo: "아메리카노", suggestedCategoryName: "카페"))))
        vm.memo = "아아 한잔여"
        await vm.polishMemo()

        #expect(vm.memo == "아메리카노")
        #expect(vm.hasPolished)
        #expect(vm.selectedCategoryID == cafe)
        _ = container
    }

    @Test func doesNotOverrideExplicitlySelectedCategory() async throws {
        let (repo, container) = try repoWithSettings(aiEnabled: true)
        let food = try catID(repo, "식비")
        let vm = QuickAddViewModel(repository: repo,
                                    aiAvailability: FakeAIAvailability(isAvailable: true),
                                    memoPolisher: FakeMemoPolisher(result: .success(MemoPolishResult(polishedMemo: "정리됨", suggestedCategoryName: "카페"))))
        vm.selectedCategoryID = food
        vm.memo = "메모"
        await vm.polishMemo()

        #expect(vm.selectedCategoryID == food)
        _ = container
    }

    @Test func silentlyFailsOnGenerationError() async throws {
        let (repo, container) = try repoWithSettings(aiEnabled: true)
        let vm = QuickAddViewModel(repository: repo,
                                    aiAvailability: FakeAIAvailability(isAvailable: true),
                                    memoPolisher: FakeMemoPolisher(result: .failure(AIError())))
        vm.memo = "원본 메모"
        await vm.polishMemo()

        #expect(vm.memo == "원본 메모")
        #expect(!vm.hasPolished)
        _ = container
    }

    @Test func emptyPolishResultKeepsOriginalMemoAndAllowsRetry() async throws {
        let (repo, container) = try repoWithSettings(aiEnabled: true)
        let vm = QuickAddViewModel(repository: repo,
                                    aiAvailability: FakeAIAvailability(isAvailable: true),
                                    memoPolisher: FakeMemoPolisher(result: .success(MemoPolishResult(polishedMemo: "  ", suggestedCategoryName: nil))))
        vm.memo = "스타벅스 아메리카노"
        await vm.polishMemo()

        #expect(vm.memo == "스타벅스 아메리카노")   // 빈 결과가 원본을 지우지 않음
        #expect(!vm.hasPolished)                    // 재시도 가능
        _ = container
    }

    @Test func editingMemoAfterPolishReenablesPolish() async throws {
        let (repo, container) = try repoWithSettings(aiEnabled: true)
        let vm = QuickAddViewModel(repository: repo,
                                    aiAvailability: FakeAIAvailability(isAvailable: true),
                                    memoPolisher: FakeMemoPolisher(result: .success(MemoPolishResult(polishedMemo: "아메리카노", suggestedCategoryName: nil))))
        vm.memo = "아아"
        await vm.polishMemo()
        #expect(vm.hasPolished)

        vm.memo = "아메리카노 법인카드"   // 다듬은 뒤 사용자가 수정
        #expect(!vm.hasPolished)          // 다시 다듬을 수 있어야 한다
        _ = container
    }

    @Test func concurrentUserEditIsNotOverwrittenByPolishResult() async throws {
        let (repo, container) = try repoWithSettings(aiEnabled: true)
        let gated = GatedMemoPolisher(result: MemoPolishResult(polishedMemo: "다듬어진 메모", suggestedCategoryName: nil))
        let vm = QuickAddViewModel(repository: repo,
                                    aiAvailability: FakeAIAvailability(isAvailable: true),
                                    memoPolisher: gated)
        vm.memo = "원본"
        let polishing = Task { await vm.polishMemo() }
        for _ in 0..<10_000 where !gated.started { await Task.yield() }

        vm.memo = "원본 수정함"   // 생성 중 사용자가 편집
        gated.open()
        await polishing.value

        #expect(vm.memo == "원본 수정함")   // AI 결과가 사용자의 최신 입력을 덮지 않음
        #expect(!vm.hasPolished)
        _ = container
    }

    @Test func hidesPolishButtonWhenAIDisabled() throws {
        let (repo, container) = try repoWithSettings(aiEnabled: false)
        let vm = QuickAddViewModel(repository: repo,
                                    aiAvailability: FakeAIAvailability(isAvailable: true),
                                    memoPolisher: FakeMemoPolisher())
        vm.memo = "메모"
        #expect(!vm.showsPolishButton)
        _ = container
    }

    @Test func hidesPolishButtonWhenMemoEmpty() throws {
        let (repo, container) = try repoWithSettings(aiEnabled: true)
        let vm = QuickAddViewModel(repository: repo,
                                    aiAvailability: FakeAIAvailability(isAvailable: true),
                                    memoPolisher: FakeMemoPolisher())
        vm.memo = ""
        #expect(!vm.showsPolishButton)
        _ = container
    }
}
