import Testing
@testable import WadeMoney

/// 이 테스트는 타입이 프로토콜을 준수하고 컴파일되는지만 확인한다.
/// 시뮬레이터에서 실제 온디바이스 생성이 보장되지 않으므로 메서드 호출(.generate/.polish/.narrate/.isAvailable)은 하지 않는다.
struct FoundationModelsAIServicesTests {
    @Test func realImplementationsConformToProtocols() {
        let _: InsightGenerating = FoundationModelsInsightGenerator()
        let _: MemoPolishing = FoundationModelsMemoPolisher()
        let _: ReportNarrating = FoundationModelsReportNarrator()
        let _: AIAvailabilityChecking = SystemLanguageModelAvailability()
        #expect(true)
    }
}
