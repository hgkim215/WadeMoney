# WadeMoney — AI (Foundation Models) Implementation Plan (5/6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iOS 26 온디바이스 Foundation Models로 세 가지 AI 기능을 붙인다 — (1) 대시보드 AI 인사이트 카드, (2) 빠른 입력 시트의 "AI 다듬기"(메모 다듬기 + 카테고리 추천), (3) 대시보드 하위 AI 리포트 화면. 세 기능 모두 **숫자는 Swift가 계산, 문장은 LLM이 서술** 원칙을 지킨다: LLM에는 이미 계산된 수치·이름 문자열만 입력으로 주고, 화면에 표시되는 모든 금액·비율·태그(양호/주의)는 Swift가 직접 계산해 렌더링한다. LLM 출력은 오직 자연어 문장(1~2개)뿐이다.

**Architecture:** `InsightGenerating`/`MemoPolishing`/`ReportNarrating` 프로토콜 시임을 두고, 실제 구현은 Foundation Models(`SystemLanguageModel`/`LanguageModelSession`/`@Generable`/`@Guide`)로, 테스트는 Fake 구현체로 검증한다. 온디바이스 생성은 시뮬레이터에서 정상 동작하지 않을 수 있으므로(실기기·Apple Intelligence 계정 필요), 실 구현체는 **컴파일 검증만** 하고 자동화 테스트에서는 절대 호출하지 않는다. 뷰모델은 기존 패턴대로 `now`/`calendar`를 주입받고, AI 가용성(`SystemLanguageModel.default.isAvailable`)과 설정의 `aiEnabled` 토글을 모두 만족할 때만 AI UI를 노출한다(비활성 시 완전히 숨김, 흐리게 표시하지 않음).

**Tech Stack:** SwiftUI, `@Observable`, SwiftData, `WadeMoneyCore`, **FoundationModels**(iOS 26+, on-device), Swift Testing, XcodeGen, iOS 26 시뮬레이터.

## Foundation Models API 확인 (근거)

계획 작성 전 Xcode 26.6 SDK의 실제 선언을 직접 확인했다(`.../iPhoneSimulator.sdk/.../FoundationModels.framework/Modules/FoundationModels.swiftmodule/arm64-apple-ios-simulator.swiftinterface`). 이 계획의 모든 코드는 아래 실제 시그니처를 따른다:

- `SystemLanguageModel.default: SystemLanguageModel`, `var isAvailable: Bool { get }`, `var availability: Availability { get }` (`.available` / `.unavailable(UnavailableReason)`)
- `LanguageModelSession(model: SystemLanguageModel = .default, instructions: String? = nil)` (그 외 tools/Instructions 빌더 오버로드 있음)
- `session.respond<Content: Generable>(to prompt: String, generating type: Content.Type, options: GenerationOptions = .init()) async throws -> Response<Content>` (`response.content`가 결과)
- `@Generable(description: String? = nil)` 매크로(구조체에 부착), `@Guide(description: String? = nil, _ guides: GenerationGuide<T>...)` 매크로(프로퍼티에 부착)
- 에러: `LanguageModelSession.GenerationError` — `.exceededContextWindowSize`, `.guardrailViolation`, `.rateLimited`, `.decodingFailure` 등 (전부 `Swift.Error` 준수, `try await`로 캐치)
- 최소 iOS 버전: `iOS 26.0` — 프로젝트 배포 타깃과 이미 일치하므로 별도 `@available` 어노테이션 불필요.

## Global Constraints

- **범위**: AI 인사이트 카드, AI 다듬기, AI 리포트 화면 + 이를 지원하는 프로토콜/구현체. 위젯·App Intents는 계획 6.
- **디자인 정본**: `docs/design/app-design-specification-analysis/project/WadeMoney 가계부.dc.html`의 AI 인사이트 카드(§5.1-5), AI 리포트(§5.5), 빠른 입력의 AI 다듬기(§5.6). 토큰은 `WadeColors`/`WadeFont`/`WadeRadius`/`WadeSpacing`/`Icon`만 사용. AI 관련 배경은 `aitint1`/`aitint2` 그라데이션, 팁 카드는 `primarysoft`.
- **숫자는 Swift가 계산, 문장은 LLM이 서술**: LLM 입력에는 원시 거래 내역을 절대 넘기지 않는다 — 이미 포매팅된 문자열(예: `"120,000"`, `"12%"`, `"식비"`)만 넘긴다. 화면에 표시되는 태그(양호/주의)·금액·퍼센트는 전부 Swift가 계산해 렌더링하고, LLM 출력(`@Generable` 구조체)은 자연어 문장 필드만 갖는다.
- **AI 게이팅**: 세 기능 모두 `SettingsStore.settings().aiEnabled == true` **그리고** `SystemLanguageModel.default.isAvailable == true`일 때만 노출. 하나라도 아니면 UI 자체를 완전히 숨긴다(비활성 스타일로 보여주지 않음).
- **에러 표면화 정책(계획 2~4 백로그 항목 해소)**: AI 생성 실패는 조용히 성능 저하(silent degrade)한다 — 인사이트 카드는 숨겨지고, 메모 다듬기는 원본 메모를 유지하며, 리포트는 서술 문장만 비고 숫자 카드는 그대로 표시된다. 토스트/에러 얼럿을 띄우지 않는다. 이는 실기기 없이는 실패 원인(모델 다운로드 중, guardrail, 컨텍스트 초과 등)을 사용자에게 유의미하게 설명할 수 없고, AI는 부가 기능이지 핵심 흐름이 아니기 때문— 이 계획에서 의도적으로 결정하고 테스트로 고정한다(기존 `try?`처럼 우연히 삼켜지는 게 아니라 명시적 `do/catch`로 문서화).
- **실 구현체는 호출 금지**: `FoundationModelsInsightGenerator`/`FoundationModelsMemoPolisher`/`FoundationModelsReportNarrator`/`SystemLanguageModelAvailability`(태스크 3)는 시뮬레이터에서 실제 생성이 보장되지 않으므로, 자동화 테스트에서 **`.generate()`/`.polish()`/`.narrate()`/`.isAvailable`을 호출하지 않는다.** 타입이 프로토콜을 준수하는지(컴파일)만 확인한다. 모든 뷰모델 테스트는 Fake 구현체(`WadeMoneyTests/Support/FakeAIServices.swift`)를 주입해 사용한다.
- **엔진 순수성 유지**: 새 Core 함수(`PaceCalculator.categoryPace`)도 기존 원칙을 따른다 — `Date()`/`Calendar.current` 직접 호출 금지, `now`/`calendar` 인자로만 시간을 받는다. AI 프로토콜/뷰모델도 동일.
- **빌드/테스트**(서명 없이): `xcodegen generate` → `xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`. Swift Testing 결과는 "Test run with N tests ... passed" 라인으로 확인. SourceKit IDE의 "No such module" 류는 오류 아님. `import FoundationModels`가 포함된 파일도 동일 커맨드로 빌드·링크된다(시뮬레이터 SDK에 프레임워크가 존재함을 확인했다) — 컴파일은 항상 되고, 오직 *실행 시점의 실제 생성*만 실기기가 필요하다.
- **화면 수동 검증**: 뷰 태스크는 빌드 + 시뮬레이터 스크린샷으로 확인. AI가 실제로 문장을 생성하지 못하는 시뮬레이터 환경에서는 `insightText`/`summarySentence` 등이 `nil`이라 카드가 비거나 숨겨지는 게 **정상**이다 — 이 경우 Fake를 임시로 주입한 디버그 빌드로 시각 검증하거나, 조건부 로직(카드 숨김/빈 값 처리)이 크래시 없이 동작하는지만 확인한다.
- SwiftData 테스트 헬퍼는 반드시 `ModelContainer`를 보유(미보유 시 dealloc 크래시).
- `.build/`·`*.xcodeproj`·`DerivedData/` 추적 금지. 커밋은 자주.
- 시작 테스트 수: 61 (계획 4 + 정리 계획 종료 시점). 각 태스크가 누적 증가.

---

### Task 1: 카테고리별 페이스 비교 (`WadeMoneyCore`)

AI 리포트의 "지난달 대비 변화" 카드에 필요한 카테고리별 동일시점 비교를 순수 계산 레이어에 추가한다. 기존 `PaceCalculator.pace`(전체 합계 비교)와 동일한 날짜 슬라이싱 로직을 카테고리별로 반복한다.

**Files:**
- Modify: `WadeMoneyCore/Sources/WadeMoneyCore/Aggregator.swift`
- Modify: `WadeMoneyCore/Sources/WadeMoneyCore/PaceCalculator.swift`
- Test: `WadeMoneyCore/Tests/WadeMoneyCoreTests/PaceCalculatorTests.swift`

**Interfaces:**
- `Aggregator.totalsByCategory(_:from:to:) -> [CategoryTotal]` (날짜 범위 오버로드, 기존 `in period:`가 이를 호출하도록 리팩터)
- `struct CategoryPaceItem: Equatable, Sendable { categoryID, currentCumulative, priorCumulative, deltaRatio }`
- `PaceCalculator.categoryPace(kind:containing:asOf:txns:) -> [CategoryPaceItem]` — 현재 또는 이전 구간에 지출이 있는 카테고리만, `currentCumulative` 내림차순

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyCore/Tests/WadeMoneyCoreTests/PaceCalculatorTests.swift`에 추가:

```swift
extension PaceCalculatorTests {
    @Test func categoryPaceComparesEachCategorySamePoint() {
        let cafe = UUID()
        let txns = [
            // 식비: 6월 1~15일 10만, 7월 1~15일 12만 (증가)
            TransactionRecord(amount: 100_000, type: .expense, categoryID: food, date: TS.date(2026, 6, 5)),
            TransactionRecord(amount: 120_000, type: .expense, categoryID: food, date: TS.date(2026, 7, 10)),
            // 카페: 6월 1~15일 4만, 7월 1~15일 1만 (감소)
            TransactionRecord(amount: 40_000, type: .expense, categoryID: cafe, date: TS.date(2026, 6, 6)),
            TransactionRecord(amount: 10_000, type: .expense, categoryID: cafe, date: TS.date(2026, 7, 6)),
        ]
        let items = pace.categoryPace(kind: .month, containing: TS.date(2026, 7, 1), asOf: TS.date(2026, 7, 15, 12), txns: txns)

        let foodItem = try? #require(items.first { $0.categoryID == food })
        #expect(foodItem??.currentCumulative == 120_000)
        #expect(foodItem??.priorCumulative == 100_000)
        #expect(foodItem??.deltaRatio == Decimal(20_000) / Decimal(100_000))

        let cafeItem = try? #require(items.first { $0.categoryID == cafe })
        #expect(cafeItem??.currentCumulative == 10_000)
        #expect(cafeItem??.priorCumulative == 40_000)
        #expect(cafeItem??.deltaRatio == Decimal(-30_000) / Decimal(40_000))

        // currentCumulative 내림차순
        #expect(items.first?.categoryID == food)
    }

    @Test func categoryPaceNilRatioWhenNoPriorSpending() {
        let txns = [
            TransactionRecord(amount: 15_000, type: .expense, categoryID: food, date: TS.date(2026, 7, 3)),
        ]
        let items = pace.categoryPace(kind: .month, containing: TS.date(2026, 7, 1), asOf: TS.date(2026, 7, 15), txns: txns)
        #expect(items.first?.deltaRatio == nil)
    }

    @Test func categoryPaceExcludesCategoriesWithNoActivity() {
        let cafe = UUID()
        let txns = [
            TransactionRecord(amount: 15_000, type: .expense, categoryID: food, date: TS.date(2026, 7, 3)),
        ]
        let items = pace.categoryPace(kind: .month, containing: TS.date(2026, 7, 1), asOf: TS.date(2026, 7, 15), txns: txns)
        #expect(!items.contains { $0.categoryID == cafe })
    }
}
```

(주: `#require`를 옵셔널 체이닝에 두 번 감싼 임시 표기는 실제 구현 시 `let foodItem = try #require(items.first { $0.categoryID == food })`처럼 단순화해도 된다 — 컴파일되는 형태로 정리해서 작성할 것.)

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd WadeMoneyCore && swift test --filter PaceCalculatorTests`. `categoryPace` 미정의로 컴파일 실패해야 한다.

- [ ] **Step 3: 구현**

`Aggregator.swift`에서 기존 함수를 리팩터하고 오버로드 추가:

```swift
public static func totalsByCategory(_ txns: [TransactionRecord], in period: Period) -> [CategoryTotal] {
    totalsByCategory(txns, from: period.start, to: period.end)
}

public static func totalsByCategory(_ txns: [TransactionRecord], from start: Date, to end: Date) -> [CategoryTotal] {
    var buckets: [UUID?: Decimal] = [:]
    for t in txns where t.type == .expense && t.date >= start && t.date < end {
        buckets[t.categoryID, default: 0] += t.amount
    }
    return buckets
        .map { CategoryTotal(categoryID: $0.key, total: $0.value) }
        .sorted { $0.total > $1.total }
}
```

`PaceCalculator.swift`에 추가:

```swift
public struct CategoryPaceItem: Equatable, Sendable {
    public let categoryID: UUID?
    public let currentCumulative: Decimal
    public let priorCumulative: Decimal
    public let deltaRatio: Decimal?

    public init(categoryID: UUID?, currentCumulative: Decimal, priorCumulative: Decimal, deltaRatio: Decimal?) {
        self.categoryID = categoryID
        self.currentCumulative = currentCumulative
        self.priorCumulative = priorCumulative
        self.deltaRatio = deltaRatio
    }
}

extension PaceCalculator {
    /// 카테고리별 동일시점 비교. 현재·이전 구간 중 하나라도 지출이 있는 카테고리만 포함, currentCumulative 내림차순.
    public func categoryPace(
        kind: PeriodKind,
        containing date: Date,
        asOf now: Date,
        txns: [TransactionRecord]
    ) -> [CategoryPaceItem] {
        let current = calc.period(kind, containing: date)
        let d = calc.daysElapsed(in: current, asOf: now)
        let currentEnd = calc.calendar.date(byAdding: .day, value: d, to: current.start)!
        let currentTotals = Aggregator.totalsByCategory(txns, from: current.start, to: currentEnd)

        let prior = calc.previous(current)
        let priorLength = calc.dayCount(of: prior)
        let priorD = min(d, priorLength)
        let priorEnd = calc.calendar.date(byAdding: .day, value: priorD, to: prior.start)!
        let priorTotals = Aggregator.totalsByCategory(txns, from: prior.start, to: priorEnd)

        var byID: [UUID?: (current: Decimal, prior: Decimal)] = [:]
        for t in currentTotals { byID[t.categoryID, default: (0, 0)].current = t.total }
        for t in priorTotals { byID[t.categoryID, default: (0, 0)].prior = t.total }

        return byID.map { categoryID, sums in
            let ratio: Decimal? = sums.prior == 0 ? nil : (sums.current - sums.prior) / sums.prior
            return CategoryPaceItem(categoryID: categoryID, currentCumulative: sums.current, priorCumulative: sums.prior, deltaRatio: ratio)
        }
        .sorted { $0.currentCumulative > $1.currentCumulative }
    }
}
```

`calc`는 `PaceCalculator`의 기존 `private let calc: PeriodCalculator` 프로퍼티 — 이 확장은 반드시 **같은 파일**(`PaceCalculator.swift`) 안에 두어 private 접근이 가능하게 한다(별도 파일 extension이면 컴파일 에러).

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd WadeMoneyCore && swift test`. 전체(신규 포함) 통과 확인.

- [ ] **Step 5: 커밋**

```
git add WadeMoneyCore/
git commit -m "feat(core): add category-level pace comparison for AI report"
```

---

### Task 2: AI 프로토콜 시임 + 가용성 + Fake 구현체

세 AI 기능의 인터페이스를 정의한다. 이 태스크는 순수 인터페이스/자료구조 추가라 새로운 분기 로직이 없으므로, TDD 대신 "구현 → 전체 테스트 그린 유지"로 검증한다(실질 동작 검증은 태스크 4·5·6의 뷰모델 테스트에서 Fake를 통해 이뤄진다).

**Files:**
- Create: `WadeMoney/AI/AIAvailability.swift`
- Create: `WadeMoney/AI/AIServices.swift`
- Create: `WadeMoneyTests/Support/FakeAIServices.swift`

**Interfaces:**
- `protocol AIAvailabilityChecking: Sendable { var isAvailable: Bool { get } }`
- `struct InsightInput: Sendable { periodLabel, totalExpenseText, paceDeltaPercentText, paceIncreased, topCategoryName?, topCategoryPercentText? }`
- `protocol InsightGenerating: Sendable { func generate(_ input: InsightInput) async throws -> String }`
- `struct MemoPolishResult: Equatable, Sendable { polishedMemo, suggestedCategoryName? }`
- `protocol MemoPolishing: Sendable { func polish(memo: String, categoryNames: [String]) async throws -> MemoPolishResult }`
- `struct ReportInput: Sendable { monthLabel, daysElapsedText, totalExpenseText, budgetStatusText, paceDeltaPercentText, paceIncreased, projectedTotalText, topIncrease: (name:String,percentText:String)?, topDecrease: (name:String,percentText:String)? }`
- `struct ReportNarration: Equatable, Sendable { summarySentence, tipSentence }`
- `protocol ReportNarrating: Sendable { func narrate(_ input: ReportInput) async throws -> ReportNarration }`
- Fakes: `FakeAIAvailability`, `FakeInsightGenerator`, `FakeMemoPolisher`, `FakeReportNarrator`(모두 `Result` 주입 가능), `SpyReportNarrator`(마지막 입력 캡처), `struct AIError: Error`

- [ ] **Step 1: 구현**

`WadeMoney/AI/AIAvailability.swift`:

```swift
import Foundation

protocol AIAvailabilityChecking: Sendable {
    var isAvailable: Bool { get }
}
```

`WadeMoney/AI/AIServices.swift`:

```swift
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
}
```

`WadeMoneyTests/Support/FakeAIServices.swift`:

```swift
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
```

- [ ] **Step 2: 빌드 + 전체 테스트 그린 확인**

Run: `xcodegen generate && xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`. 기존 61개 테스트가 그대로 통과해야 한다(신규 로직 없음, 컴파일만 확인).

- [ ] **Step 3: 커밋**

```
git add WadeMoney/AI/AIAvailability.swift WadeMoney/AI/AIServices.swift WadeMoneyTests/Support/FakeAIServices.swift
git commit -m "feat(ai): add AI protocol seams and fake implementations"
```

---

### Task 3: Foundation Models 실 구현체

`import FoundationModels`로 태스크 2의 프로토콜을 실제 온디바이스 모델로 구현한다. **자동화 테스트에서 이 구현체의 메서드를 절대 호출하지 않는다** — 컴파일·타입 준수만 확인한다(시뮬레이터에서 실제 생성이 보장되지 않으므로 호출 시 타임아웃/에러/행이 발생할 수 있다).

**Files:**
- Create: `WadeMoney/AI/FoundationModelsAIServices.swift`
- Test: `WadeMoneyTests/FoundationModelsAIServicesTests.swift`

**Interfaces:**
- `@Generable struct InsightNarrationOutput { @Guide var sentence: String }`
- `@Generable struct MemoPolishOutput { @Guide var polishedMemo: String; @Guide var suggestedCategoryName: String }`
- `@Generable struct ReportNarrationOutput { @Guide var summarySentence: String; @Guide var tipSentence: String }`
- `struct FoundationModelsInsightGenerator: InsightGenerating`
- `struct FoundationModelsMemoPolisher: MemoPolishing`
- `struct FoundationModelsReportNarrator: ReportNarrating`
- `struct SystemLanguageModelAvailability: AIAvailabilityChecking`

- [ ] **Step 1: 컴파일만 확인하는 테스트 작성**

`WadeMoneyTests/FoundationModelsAIServicesTests.swift`:

```swift
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
```

- [ ] **Step 2: 테스트 실패(컴파일 에러) 확인**

Run: `xcodebuild test ...`. 타입 미정의로 컴파일 실패해야 한다.

- [ ] **Step 3: 구현**

`WadeMoney/AI/FoundationModelsAIServices.swift`:

```swift
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
        let response = try await session.respond(to: prompt, generating: ReportNarrationOutput.self)
        return ReportNarration(summarySentence: response.content.summarySentence, tipSentence: response.content.tipSentence)
    }
}

struct SystemLanguageModelAvailability: AIAvailabilityChecking {
    var isAvailable: Bool { SystemLanguageModel.default.isAvailable }
}
```

- [ ] **Step 4: 테스트 통과(컴파일 성공) 확인**

Run: `xcodebuild test ...`. "Test run with N tests ... passed" 확인(62개 이상).

- [ ] **Step 5: 커밋**

```
git add WadeMoney/AI/FoundationModelsAIServices.swift WadeMoneyTests/FoundationModelsAIServicesTests.swift
git commit -m "feat(ai): add Foundation Models-backed AI service implementations"
```

---

### Task 4: 대시보드 AI 인사이트 카드 + 리포트 진입점

**Files:**
- Modify: `WadeMoney/Stores/LedgerRepository.swift` (aiEnabled 읽기 헬퍼)
- Modify: `WadeMoney/Screens/Dashboard/DashboardViewModel.swift`
- Modify: `WadeMoney/Screens/Dashboard/DashboardScreen.swift`
- Modify: `WadeMoney/Screens/Dashboard/DashboardComponents.swift`
- Test: `WadeMoneyTests/DashboardInsightTests.swift`

**Interfaces:**
- `LedgerRepository.aiEnabled() throws -> Bool`
- `DashboardViewModel.init(repository:now:calendar:aiAvailability: AIAvailabilityChecking = SystemLanguageModelAvailability(), insightGenerator: InsightGenerating = FoundationModelsInsightGenerator())`
- `DashboardViewModel.insightText: String?`, `insightIsGood: Bool?`, `isLoadingInsight: Bool`, `func refreshInsight() async`
- 인사이트는 `kind`가 월/연이고 페이스 비교 가능(`display.pace != nil`)할 때만 시도. 태그(양호/주의)는 `pace.direction`에서 Swift가 계산(LLM 출력 아님).

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/DashboardInsightTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct DashboardInsightTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }
    func makeRepo() throws -> (LedgerRepository, SettingsStore, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        let ctx = container.mainContext
        try CategorySeeder.seedIfNeeded(ctx)
        return (LedgerRepository(context: ctx), SettingsStore(context: ctx), container)
    }
    func catID(_ repo: LedgerRepository, _ name: String) throws -> UUID {
        try repo.allCategories(includeArchived: false).first { $0.name == name }!.id
    }
    func seedComparablePace(_ repo: LedgerRepository) throws {
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 80_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 6, 5))
        try repo.addTransaction(amount: 100_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))
    }

    @Test func loadsInsightWhenEnabledAvailableAndComparable() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setAIEnabled(true)
        try seedComparablePace(repo)

        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc,
                                     aiAvailability: FakeAIAvailability(isAvailable: true),
                                     insightGenerator: FakeInsightGenerator(result: .success("테스트 인사이트 문장")))
        vm.kind = .month
        vm.load()
        await vm.refreshInsight()

        #expect(vm.insightText == "테스트 인사이트 문장")
        #expect(vm.insightIsGood == false) // 지출 증가 → 주의
        _ = container
    }

    @Test func hidesInsightWhenAIDisabled() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setAIEnabled(false)
        try seedComparablePace(repo)

        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc,
                                     aiAvailability: FakeAIAvailability(isAvailable: true),
                                     insightGenerator: FakeInsightGenerator(result: .success("숨겨져야 함")))
        vm.kind = .month
        vm.load()
        await vm.refreshInsight()

        #expect(vm.insightText == nil)
        _ = container
    }

    @Test func hidesInsightWhenModelUnavailable() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setAIEnabled(true)
        try seedComparablePace(repo)

        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc,
                                     aiAvailability: FakeAIAvailability(isAvailable: false),
                                     insightGenerator: FakeInsightGenerator(result: .success("숨겨져야 함")))
        vm.kind = .month
        vm.load()
        await vm.refreshInsight()

        #expect(vm.insightText == nil)
        _ = container
    }

    @Test func hidesInsightOnDayViewNoPace() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setAIEnabled(true)
        try seedComparablePace(repo)

        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc,
                                     aiAvailability: FakeAIAvailability(isAvailable: true),
                                     insightGenerator: FakeInsightGenerator(result: .success("숨겨져야 함")))
        vm.kind = .day
        vm.load()
        await vm.refreshInsight()

        #expect(vm.insightText == nil)
        _ = container
    }

    @Test func fallsBackSilentlyOnGenerationFailure() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setAIEnabled(true)
        try seedComparablePace(repo)

        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc,
                                     aiAvailability: FakeAIAvailability(isAvailable: true),
                                     insightGenerator: FakeInsightGenerator(result: .failure(AIError())))
        vm.kind = .month
        vm.load()
        await vm.refreshInsight()

        #expect(vm.insightText == nil)
        _ = container
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ...`. `aiAvailability`/`insightGenerator` 파라미터·`refreshInsight`/`insightText` 미정의로 컴파일 실패해야 한다.

- [ ] **Step 3: 구현**

`LedgerRepository.swift`에 추가:

```swift
func aiEnabled() throws -> Bool {
    try SettingsStore(context: context).settings().aiEnabled
}
```

`DashboardViewModel.swift` 수정 — `init`과 프로퍼티 추가:

```swift
private let repository: LedgerRepository
private let now: Date
private let calendar: Calendar
private let aiAvailability: AIAvailabilityChecking
private let insightGenerator: InsightGenerating

var kind: PeriodKind = .month
var offset: Int = 0
private(set) var display: DashboardDisplay?
private(set) var insightText: String?
private(set) var insightIsGood: Bool?
private(set) var isLoadingInsight = false

init(
    repository: LedgerRepository, now: Date, calendar: Calendar,
    aiAvailability: AIAvailabilityChecking = SystemLanguageModelAvailability(),
    insightGenerator: InsightGenerating = FoundationModelsInsightGenerator()
) {
    self.repository = repository
    self.now = now
    self.calendar = calendar
    self.aiAvailability = aiAvailability
    self.insightGenerator = insightGenerator
}

func refreshInsight() async {
    guard
        let d = display, let pace = d.pace,
        aiAvailability.isAvailable,
        (try? repository.aiEnabled()) == true
    else {
        insightText = nil
        return
    }
    isLoadingInsight = true
    defer { isLoadingInsight = false }
    let top = d.donut.first { !$0.isOther }
    let input = InsightInput(
        periodLabel: d.periodLabel,
        totalExpenseText: d.totalText,
        paceDeltaPercentText: pace.deltaText,
        paceIncreased: pace.direction == .up,
        topCategoryName: top?.name,
        topCategoryPercentText: top?.percentText
    )
    do {
        insightText = try await insightGenerator.generate(input)
        insightIsGood = pace.direction == .down
    } catch {
        insightText = nil
        insightIsGood = nil
    }
}
```

`DashboardComponents.swift`에 추가:

```swift
struct InsightCard: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    let isGood: Bool
    let onDetail: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Icon("auto_awesome", size: 17).foregroundStyle(WadeColors.primary(scheme))
                    Text("AI 인사이트").font(WadeFont.pretendard(13, weight: .bold)).foregroundStyle(WadeColors.ink(scheme))
                }
                Spacer()
                Text(isGood ? "양호" : "주의")
                    .font(WadeFont.pretendard(11, weight: .bold))
                    .foregroundStyle(isGood ? WadeColors.good(scheme) : WadeColors.bad(scheme))
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(isGood ? WadeColors.goodsoft(scheme) : WadeColors.badsoft(scheme), in: Capsule())
            }
            Text(text).font(WadeFont.pretendard(13.5)).foregroundStyle(WadeColors.ink2(scheme))
            Button(action: onDetail) {
                Text("자세히 보기 ›").font(WadeFont.pretendard(12.5, weight: .bold)).foregroundStyle(WadeColors.primary(scheme))
            }.buttonStyle(.plain)
        }
        .padding(WadeSpacing.cardPadding)
        .background(
            LinearGradient(colors: [WadeColors.aitint1(scheme), WadeColors.aitint2(scheme)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: WadeRadius.card, style: .continuous)
        )
    }
}
```

`DashboardScreen.swift` 전체 교체:

```swift
import SwiftUI
import SwiftData
import WadeMoneyCore

struct DashboardScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?
    @State private var showReport = false
    var refreshToken: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: WadeSpacing.cardGap) {
                    HStack {
                        Text("한눈에").font(WadeFont.pretendard(30, weight: .heavy))
                            .foregroundStyle(WadeColors.ink(scheme))
                        Spacer()
                        Button { showReport = true } label: {
                            HStack(spacing: 5) {
                                Icon("auto_awesome", size: 15)
                                Text("리포트").font(WadeFont.pretendard(12.5, weight: .bold))
                            }
                            .foregroundStyle(WadeColors.primary(scheme))
                            .padding(.horizontal, 13).padding(.vertical, 8)
                            .background(WadeColors.primarysoft(scheme), in: Capsule())
                        }.buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)

                    if let vm = viewModel, let d = vm.display {
                        PeriodSegment(kind: Binding(get: { vm.kind }, set: { vm.kind = $0; reload(vm) }))
                        HStack(spacing: 14) {
                            Button { vm.offset -= 1; reload(vm) } label: { Icon("chevron_left", size: 19) }
                            Text(d.periodLabel).font(WadeFont.pretendard(15, weight: .bold))
                            Button { vm.offset += 1; reload(vm) } label: { Icon("chevron_right", size: 19) }
                        }
                        .foregroundStyle(WadeColors.ink2(scheme))
                        HeroBudgetCard(display: d)
                        if let insight = vm.insightText {
                            InsightCard(text: insight, isGood: vm.insightIsGood ?? true) { showReport = true }
                        }
                        DonutCard(total: d.totalText, legend: d.donut)
                        TrendCard(bars: d.trend)
                    }
                }
                .padding(.horizontal, WadeSpacing.screenH)
                .padding(.top, WadeSpacing.contentTop)
                .padding(.bottom, WadeSpacing.contentBottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WadeColors.bg(scheme))
            .navigationDestination(isPresented: $showReport) { AIReportScreen() }
            .onAppear {
                if viewModel == nil {
                    let vm = DashboardViewModel(
                        repository: LedgerRepository(context: modelContext),
                        now: Date(), calendar: .current)
                    reload(vm)
                    viewModel = vm
                }
            }
            .onChange(of: refreshToken) { if let vm = viewModel { reload(vm) } }
        }
    }

    private func reload(_ vm: DashboardViewModel) {
        vm.load()
        Task { await vm.refreshInsight() }
    }
}
```

주: `AIReportScreen`은 태스크 6에서 만든다. 이 태스크 시점엔 아직 존재하지 않으므로, 태스크 6 완료 전까지는 최소 스텁(`struct AIReportScreen: View { var body: some View { Text("리포트") } }`)을 임시로 두거나, 태스크 4·5·6을 이 순서 그대로 연속 실행해 빌드 깨짐 없이 진행한다. (서브에이전트 주도 실행 시, 태스크 순서를 그대로 지키면 태스크 6에서 실제 화면으로 교체되므로 문제 없음 — 다만 태스크 4 완료 시점의 빌드가 깨지지 않도록, 태스크 4 구현에 `AIReportScreen` 최소 스텁을 함께 포함시킨다.)

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodegen generate && xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`.

- [ ] **Step 5: 화면 수동 검증**

시뮬레이터에서 앱 실행, 대시보드 스크린샷 확인. AI가 비활성(기본 시뮬레이터 = `SystemLanguageModelAvailability().isAvailable == false`)이므로 인사이트 카드는 보이지 않는 것이 **정상**이다 — 이 경우 크래시 없이 나머지 카드(히어로/도넛/추세)가 정상 렌더링되는지, 헤더의 "리포트" 알약 버튼이 스펙대로(auto_awesome + primarysoft 알약) 보이는지 확인한다.

- [ ] **Step 6: 커밋**

```
git add WadeMoney/
git commit -m "feat(ui): add dashboard AI insight card and report entry point"
```

---

### Task 5: 빠른 입력 "AI 다듬기"

**Files:**
- Modify: `WadeMoney/Screens/QuickAdd/QuickAddViewModel.swift`
- Modify: `WadeMoney/Screens/QuickAdd/QuickAddSheet.swift`
- Test: `WadeMoneyTests/QuickAddPolishTests.swift`

**Interfaces:**
- `QuickAddViewModel.init(repository:editing:aiAvailability: AIAvailabilityChecking = SystemLanguageModelAvailability(), memoPolisher: MemoPolishing = FoundationModelsMemoPolisher())`
- `showsPolishButton: Bool`, `isPolishing: Bool`, `hasPolished: Bool`, `polishNote: String?`, `func polishMemo() async`
- 카테고리 추천은 지출 타입 & 카테고리 미선택일 때만 자동 반영(사용자가 이미 고른 카테고리를 덮어쓰지 않음).

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/QuickAddPolishTests.swift`:

```swift
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
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ...`.

- [ ] **Step 3: 구현**

`QuickAddViewModel.swift` 수정:

```swift
private let repository: LedgerRepository
private let aiAvailability: AIAvailabilityChecking
private let memoPolisher: MemoPolishing

var amountDigits: String = ""
var type: TransactionKind = .expense { didSet { if type == .income { selectedCategoryID = nil } } }
var selectedCategoryID: UUID?
var memo: String = ""
private(set) var categories: [CategoryRef] = []
private let editingID: UUID?
var isEditing: Bool { editingID != nil }
private(set) var isPolishing = false
private(set) var hasPolished = false
private(set) var polishNote: String?

var showsPolishButton: Bool {
    !memo.trimmingCharacters(in: .whitespaces).isEmpty
        && aiAvailability.isAvailable
        && (try? repository.aiEnabled()) == true
}

init(
    repository: LedgerRepository, editing: TransactionRecord? = nil,
    aiAvailability: AIAvailabilityChecking = SystemLanguageModelAvailability(),
    memoPolisher: MemoPolishing = FoundationModelsMemoPolisher()
) {
    self.repository = repository
    self.aiAvailability = aiAvailability
    self.memoPolisher = memoPolisher
    self.categories = (try? repository.allCategories(includeArchived: false)) ?? []
    if let editing {
        self.editingID = editing.id
        self.amountDigits = "\(NSDecimalNumber(decimal: editing.amount).intValue)"
        self.type = editing.type == .income ? .income : .expense
        self.selectedCategoryID = editing.categoryID
        self.memo = editing.memo ?? ""
    } else {
        self.editingID = nil
    }
}

func polishMemo() async {
    guard !isPolishing, !memo.isEmpty else { return }
    isPolishing = true
    defer { isPolishing = false }
    do {
        let names = categories.map(\.name)
        let result = try await memoPolisher.polish(memo: memo, categoryNames: names)
        memo = result.polishedMemo
        hasPolished = true
        if type == .expense, selectedCategoryID == nil,
           let name = result.suggestedCategoryName,
           let match = categories.first(where: { $0.name == name }) {
            selectedCategoryID = match.id
            polishNote = "메모를 다듬고 \(match.name) 카테고리를 추천했어요"
        } else {
            polishNote = nil
        }
    } catch {
        // 조용히 실패 — 메모는 원본 유지, 버튼은 원상태로.
    }
}
```

(기존 `amountDecimal`/`canSave`/`tapKey`/`backspace`/`save`/`delete`는 그대로 둔다.)

`QuickAddSheet.swift`의 메모 필드 부분을 교체:

```swift
VStack(alignment: .leading, spacing: 6) {
    HStack(spacing: 8) {
        TextField("메모 (선택)", text: Binding(get: { vm.memo }, set: { vm.memo = $0 }))
            .font(WadeFont.pretendard(14.5))
        if vm.showsPolishButton || vm.hasPolished {
            Button {
                Task { await vm.polishMemo() }
            } label: {
                HStack(spacing: 4) {
                    if vm.isPolishing {
                        ProgressView().controlSize(.mini)
                    } else {
                        Icon("auto_awesome", size: 14)
                    }
                    Text(vm.hasPolished ? "정리됨" : "AI 다듬기").font(WadeFont.pretendard(11.5, weight: .bold))
                }
                .foregroundStyle(WadeColors.primary(scheme))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(WadeColors.aitint2(scheme), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(vm.isPolishing || vm.hasPolished)
        }
    }
    .padding(13)
    .background(WadeColors.card2(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.segment))

    if let note = vm.polishNote {
        Text(note).font(WadeFont.pretendard(11.5)).foregroundStyle(WadeColors.primary(scheme))
    }
}
```

(원래 있던 단독 `TextField(...)` 줄을 이 `VStack` 블록으로 교체한다.)

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodegen generate && xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`.

- [ ] **Step 5: 화면 수동 검증**

빠른 입력 시트 스크린샷 확인. 메모가 비어있으면 버튼이 안 보이는 게 정상(글자 입력 후 재확인). AI 비활성 시뮬레이터에서는 메모를 입력해도 버튼이 안 보이는 게 정상(가용성 게이트) — 크래시 없이 나머지 시트 UI가 정상인지 확인.

- [ ] **Step 6: 커밋**

```
git add WadeMoney/Screens/QuickAdd/
git commit -m "feat(ui): add AI memo polish button to quick-add sheet"
```

---

### Task 6: AI 리포트 화면

항상 이번 달(현재 월, offset 0) 기준으로 리포트를 구성한다(디자인 헤더가 "{월} 소비 리포트"로 월 고정 문구이기 때문 — 대시보드에서 선택한 기간과 무관).

**Files:**
- Create: `WadeMoney/Screens/Report/AIReportViewModel.swift`
- Create: `WadeMoney/Screens/Report/AIReportScreen.swift` (태스크 4의 스텁을 대체)
- Test: `WadeMoneyTests/AIReportViewModelTests.swift`

**Interfaces:**
- `AIReportViewModel.init(repository:now:calendar:narrator: ReportNarrating = FoundationModelsReportNarrator())`
- `func load() async`, `display: Display?`
- `Display { monthLabel, monthShortLabel, daysElapsedText, totalText, tag, isGood, summarySentence?, projectedText?, overBudgetText?, changes: [CategoryChange], tipSentence? }`
- 서술 문장(`summarySentence`/`tipSentence`)은 `narrator` 실패 시 `nil` — 숫자 카드는 그대로 표시(부분 실패 허용).

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/AIReportViewModelTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct AIReportViewModelTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int, _ hh: Int = 0) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d; comps.hour = hh
        return utc.date(from: comps)!
    }
    func makeRepo() throws -> (LedgerRepository, SettingsStore, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        let ctx = container.mainContext
        try CategorySeeder.seedIfNeeded(ctx)
        return (LedgerRepository(context: ctx), SettingsStore(context: ctx), container)
    }
    func catID(_ repo: LedgerRepository, _ name: String) throws -> UUID {
        try repo.allCategories(includeArchived: false).first { $0.name == name }!.id
    }

    @Test func computesSummaryProjectionAndCategoryChanges() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(300_000, for: YearMonth(year: 2026, month: 7))
        let food = try catID(repo, "식비"); let cafe = try catID(repo, "카페")
        try repo.addTransaction(amount: 50_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 6, 5))
        try repo.addTransaction(amount: 100_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))
        try repo.addTransaction(amount: 40_000, type: .expense, categoryID: cafe, memo: nil, date: date(2026, 6, 6))
        try repo.addTransaction(amount: 10_000, type: .expense, categoryID: cafe, memo: nil, date: date(2026, 7, 6))

        let spy = SpyReportNarrator(result: .success(ReportNarration(summarySentence: "요약", tipSentence: "팁")))
        let vm = AIReportViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc, narrator: spy)
        await vm.load()

        let d = try #require(vm.display)
        #expect(d.totalText == "110,000")
        #expect(d.summarySentence == "요약")
        #expect(d.tipSentence == "팁")
        #expect(d.changes.contains { $0.name == "식비" && $0.increased })
        #expect(d.changes.contains { $0.name == "카페" && !$0.increased })
        #expect(spy.lastInput?.monthLabel.contains("7월") == true)
        _ = container
    }

    @Test func summarySentenceNilWhenNarratorFailsButNumbersStillShow() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(300_000, for: YearMonth(year: 2026, month: 7))
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 50_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))

        let vm = AIReportViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc,
                                    narrator: SpyReportNarrator(result: .failure(AIError())))
        await vm.load()

        #expect(vm.display?.summarySentence == nil)
        #expect(vm.display?.tipSentence == nil)
        #expect(vm.display?.totalText == "50,000")
        _ = container
    }

    @Test func overBudgetTextSetWhenProjectedExceedsBudget() async throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(30_000, for: YearMonth(year: 2026, month: 7))
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 100_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 1))

        let vm = AIReportViewModel(repository: repo, now: date(2026, 7, 1, 12), calendar: utc,
                                    narrator: SpyReportNarrator(result: .success(ReportNarration(summarySentence: "s", tipSentence: "t"))))
        await vm.load()

        #expect(vm.display?.overBudgetText != nil)
        _ = container
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ...`.

- [ ] **Step 3: 구현**

`WadeMoney/Screens/Report/AIReportViewModel.swift`:

```swift
import Foundation
import Observation
import WadeMoneyCore

@MainActor
@Observable
final class AIReportViewModel {
    struct CategoryChange: Equatable, Identifiable {
        let id: UUID
        let name: String
        let iconName: String
        let colorHex: String
        let percentText: String
        let increased: Bool
    }
    struct Display: Equatable {
        let monthLabel: String
        let monthShortLabel: String
        let daysElapsedText: String
        let totalText: String
        let tag: String
        let isGood: Bool
        let summarySentence: String?
        let projectedText: String?
        let overBudgetText: String?
        let changes: [CategoryChange]
        let tipSentence: String?
    }

    private let repository: LedgerRepository
    private let now: Date
    private let calendar: Calendar
    private let narrator: ReportNarrating

    private(set) var display: Display?
    private(set) var isLoading = false

    init(repository: LedgerRepository, now: Date, calendar: Calendar, narrator: ReportNarrating = FoundationModelsReportNarrator()) {
        self.repository = repository
        self.now = now
        self.calendar = calendar
        self.narrator = narrator
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard
            let summary = try? repository.dashboardSummary(kind: .month, offset: 0, now: now, calendar: calendar),
            let categories = try? repository.allCategories(includeArchived: true),
            let txns = try? repository.allTransactions(),
            let monthStartDay = try? repository.settingsMonthStartDay()
        else {
            display = nil
            return
        }

        let calc = PeriodCalculator(calendar: calendar, monthStartDay: monthStartDay)
        let elapsed = calc.daysElapsed(in: summary.period, asOf: now)
        let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        let categoryPace = PaceCalculator(calc: calc).categoryPace(kind: .month, containing: now, asOf: now, txns: txns)
        let changes: [CategoryChange] = categoryPace.compactMap { item in
            guard let cid = item.categoryID, let ratio = item.deltaRatio, let cat = byID[cid] else { return nil }
            let pct = Int((abs(ratio) * 100).doubleValue.rounded())
            return CategoryChange(id: cid, name: cat.name, iconName: cat.iconName, colorHex: cat.colorHex,
                                   percentText: "\(pct)%", increased: ratio > 0)
        }

        let increased = (summary.pace?.deltaRatio).map { $0 > 0 } ?? false
        let isGood = !increased
        let overBudget: Decimal? = {
            guard let budget = summary.budget, let projected = summary.projected, projected > budget else { return nil }
            return projected - budget
        }()

        let topIncrease = changes.first { $0.increased }
        let topDecrease = changes.first { !$0.increased }
        let monthLabel = PeriodLabel.text(kind: .month, period: summary.period, now: now, calendar: calendar)
        let monthComponent = calendar.component(.month, from: summary.period.start)

        let input = ReportInput(
            monthLabel: monthLabel,
            daysElapsedText: "\(elapsed)일",
            totalExpenseText: Won.string(summary.totalExpense),
            budgetStatusText: overBudget != nil ? "예산 초과 예상 +\(Won.string(overBudget!))원" : "예산 내 예상",
            paceDeltaPercentText: summary.pace?.deltaRatio.map { "\(Int((abs($0) * 100).doubleValue.rounded()))%" } ?? "0%",
            paceIncreased: increased,
            projectedTotalText: summary.projected.map { Won.string($0) } ?? "-",
            topIncrease: topIncrease.map { (name: $0.name, percentText: $0.percentText) },
            topDecrease: topDecrease.map { (name: $0.name, percentText: $0.percentText) }
        )

        let narration = try? await narrator.narrate(input)

        display = Display(
            monthLabel: monthLabel,
            monthShortLabel: "\(monthComponent)월",
            daysElapsedText: input.daysElapsedText,
            totalText: input.totalExpenseText,
            tag: isGood ? "양호" : "주의",
            isGood: isGood,
            summarySentence: narration?.summarySentence,
            projectedText: summary.projected.map { Won.string($0) },
            overBudgetText: overBudget.map { "+\(Won.string($0))원" },
            changes: changes,
            tipSentence: narration?.tipSentence
        )
    }
}
```

`WadeMoney/Screens/Report/AIReportScreen.swift`(태스크 4의 스텁을 대체):

```swift
import SwiftUI
import SwiftData
import WadeMoneyCore

struct AIReportScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AIReportViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WadeSpacing.cardGap) {
                backRow
                header
                if let d = viewModel?.display {
                    summaryCard(d)
                    projectionCard(d)
                    if !d.changes.isEmpty { changesCard(d) }
                    if let tip = d.tipSentence { tipCard(tip) }
                    footerNote
                }
            }
            .padding(.horizontal, WadeSpacing.screenH)
            .padding(.top, WadeSpacing.contentTop)
            .padding(.bottom, WadeSpacing.contentBottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WadeColors.bg(scheme))
        .navigationBarBackButtonHidden(true)
        .task {
            if viewModel == nil {
                let vm = AIReportViewModel(repository: LedgerRepository(context: modelContext), now: Date(), calendar: .current)
                viewModel = vm
                await vm.load()
            }
        }
    }

    private var backRow: some View {
        Button { dismiss() } label: {
            HStack(spacing: 3) { Icon("chevron_left", size: 18); Text("대시보드").font(WadeFont.pretendard(14, weight: .semibold)) }
                .foregroundStyle(WadeColors.ink2(scheme))
        }.buttonStyle(.plain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Icon("auto_awesome", size: 20).foregroundStyle(WadeColors.primary(scheme))
                Text("\(viewModel?.display?.monthShortLabel ?? "") 소비 리포트")
                    .font(WadeFont.pretendard(22, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
            }
            if let d = viewModel?.display {
                Text("\(d.monthLabel) · \(d.daysElapsedText) 경과")
                    .font(WadeFont.pretendard(12.5)).foregroundStyle(WadeColors.ink3(scheme))
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let sh = WadeShadow.card(scheme)
        return content()
            .padding(WadeSpacing.cardPadding)
            .background(WadeColors.card(scheme))
            .clipShape(RoundedRectangle(cornerRadius: WadeRadius.card, style: .continuous))
            .shadow(color: sh.color, radius: sh.radius, y: sh.y)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryCard(_ d: AIReportViewModel.Display) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("이번 달 요약").font(WadeFont.pretendard(13, weight: .bold)).foregroundStyle(WadeColors.ink(scheme))
                Spacer()
                Text(d.tag)
                    .font(WadeFont.pretendard(11, weight: .bold))
                    .foregroundStyle(d.isGood ? WadeColors.good(scheme) : WadeColors.bad(scheme))
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(d.isGood ? WadeColors.goodsoft(scheme) : WadeColors.badsoft(scheme), in: Capsule())
            }
            Text(d.summarySentence ?? "이번 달 총지출은 \(d.totalText)원이에요.")
                .font(WadeFont.pretendard(14.5)).foregroundStyle(WadeColors.ink(scheme))
        }
        .padding(WadeSpacing.cardPadding)
        .background(
            LinearGradient(colors: [WadeColors.aitint1(scheme), WadeColors.aitint2(scheme)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: WadeRadius.card, style: .continuous)
        )
    }

    private func projectionCard(_ d: AIReportViewModel.Display) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("이번 달 예상 지출").font(WadeFont.pretendard(13, weight: .bold)).foregroundStyle(WadeColors.ink3(scheme))
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("₩").font(WadeFont.pretendard(14, weight: .bold))
                    Text(d.projectedText ?? "-").font(WadeFont.pretendard(26, weight: .heavy))
                }
                .foregroundStyle(WadeColors.ink(scheme))
                if let over = d.overBudgetText {
                    Text("예산 초과 예상 \(over)")
                        .font(WadeFont.pretendard(12, weight: .bold))
                        .foregroundStyle(WadeColors.bad(scheme))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(WadeColors.badsoft(scheme), in: Capsule())
                }
            }
        }
    }

    private func changesCard(_ d: AIReportViewModel.Display) -> some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text("지난달 대비 변화").font(WadeFont.pretendard(13, weight: .bold)).foregroundStyle(WadeColors.ink(scheme))
                ForEach(d.changes) { change in
                    HStack(spacing: 10) {
                        Icon(change.iconName, size: 18).foregroundStyle(Color(hex: change.colorHex))
                            .frame(width: 32, height: 32)
                            .background(Color(hex: change.colorHex).opacity(0.13), in: RoundedRectangle(cornerRadius: WadeRadius.smallTile))
                        Text(change.name).font(WadeFont.pretendard(13.5, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
                        Spacer()
                        HStack(spacing: 2) {
                            Icon(change.increased ? "arrow_drop_up" : "arrow_drop_down", size: 16)
                            Text(change.percentText).font(WadeFont.pretendard(12.5, weight: .bold))
                        }
                        .foregroundStyle(change.increased ? WadeColors.bad(scheme) : WadeColors.good(scheme))
                    }
                }
            }
        }
    }

    private func tipCard(_ tip: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Icon("lightbulb", size: 19).foregroundStyle(WadeColors.primary(scheme))
            Text(tip).font(WadeFont.pretendard(13.5)).foregroundStyle(WadeColors.ink(scheme))
        }
        .padding(WadeSpacing.cardPadding)
        .background(WadeColors.primarysoft(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.card, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footerNote: some View {
        HStack(spacing: 5) {
            Icon("lock", size: 13)
            Text("온디바이스에서 생성됨 · 데이터는 기기를 벗어나지 않아요")
                .font(WadeFont.pretendard(11))
        }
        .foregroundStyle(WadeColors.ink3(scheme))
        .frame(maxWidth: .infinity)
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodegen generate && xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`.

- [ ] **Step 5: 화면 수동 검증**

대시보드 헤더의 "리포트" 버튼 탭 → AI 리포트 화면 진입. 뒤로("‹ 대시보드") 동작, 예상 지출 카드, 카테고리 변화 목록(시드 데이터가 있으면), 푸터 잠금 문구 스크린샷으로 확인. 시뮬레이터에서는 `summarySentence`/`tipSentence`가 `nil`이라 요약 카드는 폴백 문장("이번 달 총지출은 …")을, 팁 카드는 아예 안 보이는 게 정상 — 크래시 없이 숫자 카드들이 정상 렌더링되는지가 핵심 확인 포인트.

- [ ] **Step 6: 커밋**

```
git add WadeMoney/Screens/Report/
git commit -m "feat(ui): add AI report screen"
```

---

## Final Review 가이드 (서브에이전트 주도 실행 시)

전체 브랜치 리뷰(opus)에서 특히 아래를 확인한다:
- 세 진입점(인사이트 카드/AI 다듬기 버튼/리포트 버튼) 모두 `aiEnabled == false` 또는 `isAvailable == false`일 때 완전히 숨겨지는지(흐리게 표시 X).
- LLM에 원시 거래 배열이 전달되는 경로가 없는지(`InsightInput`/`ReportInput`/`polish(memo:categoryNames:)` 외의 다른 데이터 전달 경로 없음).
- 화면에 렌더링되는 모든 숫자(금액/퍼센트/태그)가 Swift 계산값이고 `@Generable` 출력 구조체에 숫자 필드가 없는지.
- 세 실 구현체(`FoundationModelsInsightGenerator` 등)가 자동화 테스트에서 실제로 호출되지 않는지(전부 Fake 경유).
- AI 실패 시(Fake의 `.failure` 케이스) 크래시 없이 조용히 성능 저하하는지, 그리고 그 동작이 우연이 아니라 테스트로 고정돼 있는지.
- `DashboardScreen`이 `NavigationStack`으로 감싸지면서 기존 탭 전환(`RootTabView`)·새로고침(`dashboardRefreshToken`) 동작이 깨지지 않았는지.
