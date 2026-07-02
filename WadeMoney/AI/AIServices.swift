import Foundation

struct InsightInput: Sendable {
    let periodLabel: String
    let totalExpenseText: String
    let paceDeltaPercentText: String
    let paceIncreased: Bool
    let topCategoryName: String?
    let topCategoryPercentText: String?
}

protocol InsightGenerating: Sendable {
    func generate(_ input: InsightInput) async throws -> String
}

struct MemoPolishResult: Equatable, Sendable {
    let polishedMemo: String
    let suggestedCategoryName: String?
}

protocol MemoPolishing: Sendable {
    func polish(memo: String, categoryNames: [String]) async throws -> MemoPolishResult
}

struct ReportInput: Sendable {
    let monthLabel: String
    let daysElapsedText: String
    let totalExpenseText: String
    let budgetStatusText: String
    let paceDeltaPercentText: String
    let paceIncreased: Bool
    let projectedTotalText: String
    let topIncrease: (name: String, percentText: String)?
    let topDecrease: (name: String, percentText: String)?
}

struct ReportNarration: Equatable, Sendable {
    let summarySentence: String
    let tipSentence: String
}

protocol ReportNarrating: Sendable {
    func narrate(_ input: ReportInput) async throws -> ReportNarration
    /// 모델 리소스를 미리 로드해 첫 응답 지연을 줄인다. 기본 구현은 no-op.
    func prewarm()
}

extension ReportNarrating {
    func prewarm() {}
}
