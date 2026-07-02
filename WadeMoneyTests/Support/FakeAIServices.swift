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
    private(set) var callCount = 0
    private(set) var prewarmCount = 0
    var result: Result<ReportNarration, Error>
    init(result: Result<ReportNarration, Error>) { self.result = result }
    func narrate(_ input: ReportInput) async throws -> ReportNarration {
        lastInput = input
        callCount += 1
        return try result.get()
    }
    func prewarm() { prewarmCount += 1 }
}

/// open()이 불릴 때까지 polish가 완료되지 않는 폴리셔 — 생성 중 사용자 편집 보호 검증용.
final class GatedMemoPolisher: MemoPolishing, @unchecked Sendable {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var started = false
    let result: MemoPolishResult
    init(result: MemoPolishResult) { self.result = result }
    func polish(memo: String, categoryNames: [String]) async throws -> MemoPolishResult {
        started = true
        await withCheckedContinuation { continuation = $0 }
        return result
    }
    func open() {
        continuation?.resume()
        continuation = nil
    }
}

/// open()이 불릴 때까지 narrate가 완료되지 않는 내레이터 — 2단계 표시(숫자 먼저) 검증용.
final class GatedReportNarrator: ReportNarrating, @unchecked Sendable {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var started = false
    let result: ReportNarration
    init(result: ReportNarration) { self.result = result }
    func narrate(_ input: ReportInput) async throws -> ReportNarration {
        started = true
        await withCheckedContinuation { continuation = $0 }
        return result
    }
    func open() {
        continuation?.resume()
        continuation = nil
    }
}
