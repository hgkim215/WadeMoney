import Foundation
import FoundationModels

@Generable
struct InsightNarrationOutput {
    @Guide(description: "가계부 소비 인사이트 1~2문장. 한국어 존댓말. 입력으로 주어진 수치·이름만 인용하고 새로운 숫자를 만들지 않는다. 이모지 금지.")
    var sentence: String
}

@Generable
struct MemoPolishOutput {
    @Guide(description: "다듬어진 지출 메모. 한국어, 15자 이내, 원래 의미 유지, 군더더기 제거.")
    var polishedMemo: String
    @Guide(description: "입력으로 주어진 카테고리 이름 목록 중 가장 어울리는 하나를 정확히 그대로 반환. 확신이 없으면 빈 문자열.")
    var suggestedCategoryName: String
}

@Generable
struct ReportNarrationOutput {
    @Guide(description: "이번 달 소비 요약 1~2문장. 한국어 존댓말. 입력으로 주어진 수치만 인용하고 새 숫자를 만들지 않는다.")
    var summarySentence: String
    @Guide(description: "실행 가능한 절약 팁 1문장. 한국어 존댓말.")
    var tipSentence: String
}

private let aiInstructions = """
당신은 가계부 앱 WadeMoney의 어시스턴트입니다. 모든 금액과 비율은 이미 계산되어 입력으로 주어지며, \
당신은 그 값을 그대로 인용해 자연스러운 한국어 문장만 작성합니다. 스스로 숫자를 계산하거나 추정하지 마세요.
"""

struct FoundationModelsInsightGenerator: InsightGenerating {
    func generate(_ input: InsightInput) async throws -> String {
        let session = LanguageModelSession(instructions: aiInstructions)
        let prompt = """
        기간: \(input.periodLabel)
        총지출: \(input.totalExpenseText)원
        전기간 대비: \(input.paceIncreased ? "증가" : "감소") \(input.paceDeltaPercentText)
        최다 지출 카테고리: \(input.topCategoryName ?? "없음") \(input.topCategoryPercentText ?? "")
        위 정보로 1~2문장짜리 소비 인사이트를 작성해줘.
        """
        let response = try await session.respond(to: prompt, generating: InsightNarrationOutput.self)
        return response.content.sentence
    }
}

struct FoundationModelsMemoPolisher: MemoPolishing {
    func polish(memo: String, categoryNames: [String]) async throws -> MemoPolishResult {
        let session = LanguageModelSession(instructions: aiInstructions)
        let prompt = """
        원본 메모: \(memo)
        카테고리 목록: \(categoryNames.joined(separator: ", "))
        위 메모를 다듬고, 카테고리 목록 중 가장 어울리는 것을 하나 골라줘.
        """
        let response = try await session.respond(to: prompt, generating: MemoPolishOutput.self)
        let suggestion = response.content.suggestedCategoryName
        return MemoPolishResult(
            polishedMemo: response.content.polishedMemo,
            suggestedCategoryName: categoryNames.contains(suggestion) ? suggestion : nil
        )
    }
}

struct FoundationModelsReportNarrator: ReportNarrating {
    func narrate(_ input: ReportInput) async throws -> ReportNarration {
        let session = LanguageModelSession(instructions: aiInstructions)
        let prompt = """
        월: \(input.monthLabel) (\(input.daysElapsedText) 경과)
        총지출: \(input.totalExpenseText)원
        예산 상태: \(input.budgetStatusText)
        전월 대비: \(input.paceIncreased ? "증가" : "감소") \(input.paceDeltaPercentText)
        이번 달 예상 지출: \(input.projectedTotalText)원
        가장 많이 늘어난 카테고리: \(input.topIncrease.map { "\($0.name) \($0.percentText)" } ?? "없음")
        가장 많이 줄어든 카테고리: \(input.topDecrease.map { "\($0.name) \($0.percentText)" } ?? "없음")
        위 정보로 요약 문장 1~2개와 절약 팁 1문장을 작성해줘.
        """
        // 출력은 짧은 문장 2~3개뿐 — 토큰 상한으로 생성 꼬리 지연을 차단한다.
        let response = try await session.respond(
            to: prompt,
            generating: ReportNarrationOutput.self,
            options: GenerationOptions(maximumResponseTokens: 256)
        )
        return ReportNarration(summarySentence: response.content.summarySentence, tipSentence: response.content.tipSentence)
    }

    /// 리포트 화면 진입 시점에 모델 로드를 미리 시작해 첫 응답까지의 지연을 데이터 준비와 겹친다.
    func prewarm() {
        guard SystemLanguageModel.default.isAvailable else { return }
        LanguageModelSession(instructions: aiInstructions).prewarm()
    }
}

struct SystemLanguageModelAvailability: AIAvailabilityChecking {
    var isAvailable: Bool { SystemLanguageModel.default.isAvailable }
}
