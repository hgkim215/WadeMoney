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
    @Guide(description: "이번 달 소비 요약 1~2문장. 한국어 존댓말. 총지출과 '주요 발견' 중 가장 눈에 띄는 것 하나를 자연스럽게 엮는다. 입력으로 주어진 수치만 인용하고 새 숫자를 만들지 않는다.")
    var summarySentence: String
    @Guide(description: "'주요 발견' 중 하나에 근거한 실행 가능한 절약 팁 1문장. 한국어 존댓말. 새 숫자를 만들지 않는다.")
    var tipSentence: String
}

private let aiInstructions = """
당신은 가계부 앱 WadeMoney의 어시스턴트입니다. 모든 금액과 비율은 이미 계산되어 입력으로 주어지며, \
당신은 그 값을 그대로 인용해 자연스러운 한국어 문장만 작성합니다. 스스로 숫자를 계산하거나 추정하지 마세요.
"""

/// 온디바이스 생성이 드물게 스톨하면 이를 끊을 방법이 없어 호출부의 로딩 상태
/// (인사이트 스피너, 다듬기 버튼 disabled 등)가 영구 고착된다 — 상한을 두고
/// 초과 시 에러를 던져 호출부의 기존 실패 경로로 회복시킨다.
func withGenerationTimeout<T: Sendable>(
    seconds: TimeInterval = 30,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw CancellationError()
        }
        // 먼저 끝난 태스크가 결과를 결정한다 — 타임아웃이 이기면 생성 태스크는 취소된다.
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

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
        return try await withGenerationTimeout {
            try await session.respond(to: prompt, generating: InsightNarrationOutput.self).content.sentence
        }
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
        let output = try await withGenerationTimeout {
            try await session.respond(to: prompt, generating: MemoPolishOutput.self).content
        }
        let suggestion = output.suggestedCategoryName
        return MemoPolishResult(
            polishedMemo: output.polishedMemo,
            suggestedCategoryName: categoryNames.contains(suggestion) ? suggestion : nil
        )
    }
}

struct FoundationModelsReportNarrator: ReportNarrating {
    func narrate(_ input: ReportInput) async throws -> ReportNarration {
        let session = LanguageModelSession(instructions: aiInstructions)
        var lines = [
            "월: \(input.monthLabel) (\(input.daysElapsedText) 경과)",
            "총지출: \(input.totalExpenseText)원",
            "예산 상태: \(input.budgetStatusText)",
        ]
        // 비교 불가·0%면 줄 자체를 생략 — "감소 0%" 같은 문장이 나올 재료를 주지 않는다.
        if let pace = input.paceDelta {
            lines.append("전월 대비: \(pace.increased ? "증가" : "감소") \(pace.percentText)")
        }
        lines.append("이번 달 예상 지출: \(input.projectedTotalText)원")
        lines.append("가장 많이 늘어난 카테고리: \(input.topIncrease.map { "\($0.name) \($0.percentText)" } ?? "없음")")
        lines.append("가장 많이 줄어든 카테고리: \(input.topDecrease.map { "\($0.name) \($0.percentText)" } ?? "없음")")
        if !input.insightFacts.isEmpty {
            lines.append("주요 발견:")
            lines.append(contentsOf: input.insightFacts.map { "- \($0)" })
        }
        lines.append("위 정보로 요약 문장 1~2개와 절약 팁 1문장을 작성해줘. 요약은 총지출과 가장 눈에 띄는 발견을 엮고, 팁은 주요 발견 중 하나에 근거한 구체적 행동을 제안해줘.")
        let prompt = lines.joined(separator: "\n")
        // 출력은 짧은 문장 2~3개뿐 — 토큰 상한으로 생성 꼬리 지연을 차단한다.
        let output = try await withGenerationTimeout {
            try await session.respond(
                to: prompt,
                generating: ReportNarrationOutput.self,
                options: GenerationOptions(maximumResponseTokens: 256)
            ).content
        }
        return ReportNarration(summarySentence: output.summarySentence, tipSentence: output.tipSentence)
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
