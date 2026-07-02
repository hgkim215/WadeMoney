import Foundation
@testable import WadeMoney

struct AIError: Error {}

final class FakeAIAvailability: AIAvailabilityChecking, @unchecked Sendable {
    var isAvailable: Bool
    init(isAvailable: Bool) { self.isAvailable = isAvailable }
}

struct FakeInsightGenerator: InsightGenerating {
    var result: Result<String, Error> = .success("테스트 인사이트")
    func generate(_ input: InsightInput) async throws -> String { try result.get() }
}

struct FakeMemoPolisher: MemoPolishing {
    var result: Result<MemoPolishResult, Error> = .success(MemoPolishResult(polishedMemo: "다듬어진 메모", suggestedCategoryName: nil))
    func polish(memo: String, categoryNames: [String]) async throws -> MemoPolishResult { try result.get() }
}

struct FakeReportNarrator: ReportNarrating {
    var result: Result<ReportNarration, Error> = .success(ReportNarration(summarySentence: "테스트 요약", tipSentence: "테스트 팁"))
    func narrate(_ input: ReportInput) async throws -> ReportNarration { try result.get() }
}

final class SpyReportNarrator: ReportNarrating, @unchecked Sendable {
    private(set) var lastInput: ReportInput?
    var result: Result<ReportNarration, Error>
    init(result: Result<ReportNarration, Error>) { self.result = result }
    func narrate(_ input: ReportInput) async throws -> ReportNarration {
        lastInput = input
        return try result.get()
    }
}
