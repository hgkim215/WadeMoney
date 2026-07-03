# AI 리포트 화면 시각적 완성도 개선 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** AI 리포트 화면(`AIReportScreen`)의 요약·팁 문장 속 숫자를 자동으로 굵게+색깔 강조하고, AI 문장 생성 대기 중 팁 카드가 갑자기 나타나 레이아웃이 덜컹거리는 문제를 로딩 스켈레톤으로 해결한다.

**Architecture:** SwiftUI에 의존하지 않는 순수 함수(`SentenceHighlighter.spans(in:)`)로 문장 속 백분율·원화 금액을 찾아 증가/감소/중립으로 분류하고, 같은 파일의 SwiftUI 확장(`styledText`)이 이를 색깔 있는 `Text`로 조합한다. `AIReportScreen`은 기존 평문 `Text` 호출을 이 헬퍼로 교체하고, 팁 카드에 `isPlaceholder` 플래그를 추가해 로딩 중 `.redacted` 스켈레톤을 보여준다.

**Tech Stack:** SwiftUI, Swift 6 native `Regex` 리터럴, Swift Testing(`@Test`/`#expect`).

## Global Constraints

- AI 프롬프트·`ReportNarrationOutput` 스키마는 변경하지 않는다 — 강조는 순수 클라이언트측 문자열 후처리로만 수행한다.
- 새 셰이더/애니메이션 엔진을 도입하지 않는다 — SwiftUI 내장 `.redacted(reason:)`와 `.animation(_:value:)`만 사용한다.
- 색상은 반드시 기존 `WadeColors` 토큰(`bad`, `good`, `ink`)만 사용한다 — 하드코딩된 색상 금지.
- 폰트는 기존 `WadeFont.pretendard(_:weight:)`만 사용한다.
- 차트·그래프 등 목업에 없는 신규 시각 요소는 추가하지 않는다.
- 대시보드 `InsightCard`에 강조 로직을 연결하는 작업은 이번 스코프가 아니다 — `SentenceHighlighter`는 재사용 가능하도록 독립 파일로만 두고, 실제 연결은 하지 않는다.
- AI 진입점 게이트 로직(`DashboardViewModel.showsAIReportEntry`, `refreshInsight`)은 이미 올바르므로 변경하지 않는다.

---

## Task 1: SentenceHighlighter 숫자 강조 분류 로직

**Files:**
- Create: `WadeMoney/DesignSystem/SentenceHighlighter.swift`
- Test: `WadeMoneyTests/SentenceHighlighterTests.swift`

**Interfaces:**
- Produces:
  - `enum HighlightKind: Equatable { case increase, decrease, neutral }`
  - `struct HighlightSpan: Equatable { let range: Range<String.Index>; let kind: HighlightKind }`
  - `enum SentenceHighlighter { static func spans(in text: String) -> [HighlightSpan] }`

- [ ] **Step 1: Write the failing tests**

Create `WadeMoneyTests/SentenceHighlighterTests.swift`:

```swift
import Testing
@testable import WadeMoney

struct SentenceHighlighterTests {
    @Test func detectsIncreasePercentNearIncreaseKeyword() {
        let spans = SentenceHighlighter.spans(in: "카페 지출이 지난달 같은 시점보다 32% 늘었고, 전체 지출도 9.7% 많아요.")
        #expect(spans.count == 2)
        #expect(spans[0].kind == .increase)
    }

    @Test func neutralWhenNoDirectionKeywordInClause() {
        let spans = SentenceHighlighter.spans(in: "카페 지출이 지난달 같은 시점보다 32% 늘었고, 전체 지출도 9.7% 많아요.")
        #expect(spans[1].kind == .neutral)
    }

    @Test func detectsDecreaseKeyword() {
        let spans = SentenceHighlighter.spans(in: "식비가 지난달보다 8% 줄었어요.")
        #expect(spans.count == 1)
        #expect(spans[0].kind == .decrease)
    }

    @Test func detectsWonAmountPatternAsNeutralWithoutDirectionKeyword() {
        let spans = SentenceHighlighter.spans(in: "이번 달 총지출은 110,000원이에요.")
        #expect(spans.count == 1)
        #expect(spans[0].kind == .neutral)
    }

    @Test func wonAmountNearIncreaseKeywordIsIncrease() {
        let text = "총지출은 541,000원 초과했어요."
        let spans = SentenceHighlighter.spans(in: text)
        #expect(spans.count == 1)
        #expect(String(text[spans[0].range]) == "541,000원")
        #expect(spans[0].kind == .increase)
    }

    @Test func clauseBoundaryDoesNotLeakBetweenNumbers() {
        // "32%"의 절은 다음 쉼표까지("32% 늘었고")만 봐야 하므로, 뒤 절의 "줄었"이
        // 앞쪽 숫자의 분류에 영향을 주면 안 된다.
        let spans = SentenceHighlighter.spans(in: "카페는 32% 늘었고, 식비는 8% 줄었어요.")
        #expect(spans.count == 2)
        #expect(spans[0].kind == .increase)
        #expect(spans[1].kind == .decrease)
    }

    @Test func returnsEmptyForTextWithoutNumbers() {
        let spans = SentenceHighlighter.spans(in: "이번 주 카페를 줄이면 예산 안에 들어올 수 있어요.")
        #expect(spans.isEmpty)
    }

    @Test func spansAreSortedByPosition() {
        let spans = SentenceHighlighter.spans(in: "카페는 32% 늘었고, 식비는 8% 줄었어요.")
        #expect(spans[0].range.lowerBound < spans[1].range.lowerBound)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/SentenceHighlighterTests`
Expected: BUILD FAILED — `Cannot find 'SentenceHighlighter' in scope` (type doesn't exist yet)

- [ ] **Step 3: Write the implementation**

Create `WadeMoney/DesignSystem/SentenceHighlighter.swift`:

```swift
import SwiftUI

/// AI가 생성한 문장(또는 결정적 대체 문장) 안의 숫자를 증가/감소/중립으로 분류한다.
enum HighlightKind: Equatable {
    case increase
    case decrease
    case neutral
}

/// 원문 문자열 안에서 강조할 구간과 그 분류.
struct HighlightSpan: Equatable {
    let range: Range<String.Index>
    let kind: HighlightKind
}

/// AI 리포트 문장 속 숫자(백분율·원화 금액)를 찾아 굵게+색깔로 강조하기 위한 순수 로직.
/// SwiftUI 타입에 의존하지 않는 함수라 UI 없이 테스트 가능하다.
enum SentenceHighlighter {
    private static let percentPattern = /\d+(\.\d+)?%/
    private static let wonPattern = /[\d,]+원/
    private static let increaseKeywords = ["늘었", "증가", "올랐", "초과"]
    private static let decreaseKeywords = ["줄었", "감소", "내렸", "절약"]

    /// text 안에서 백분율·원화 금액 패턴을 모두 찾아 위치 순으로 정렬하고, 각각을
    /// 같은 절(다음 쉼표·마침표 전까지) 안의 방향 키워드로 분류한다.
    static func spans(in text: String) -> [HighlightSpan] {
        let percentRanges = Array(text.ranges(of: percentPattern))
        let wonRanges = Array(text.ranges(of: wonPattern))
        let allRanges = (percentRanges + wonRanges).sorted { $0.lowerBound < $1.lowerBound }
        return allRanges.map { HighlightSpan(range: $0, kind: classify($0, in: text)) }
    }

    private static func classify(_ range: Range<String.Index>, in text: String) -> HighlightKind {
        let rest = text[range.upperBound...]
        let clauseEnd = rest.firstIndex { $0 == "," || $0 == "." } ?? text.endIndex
        let clause = text[range.upperBound..<clauseEnd]
        if increaseKeywords.contains(where: { clause.contains($0) }) { return .increase }
        if decreaseKeywords.contains(where: { clause.contains($0) }) { return .decrease }
        return .neutral
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/SentenceHighlighterTests`
Expected: all 8 tests PASS

- [ ] **Step 5: Commit**

```bash
git add WadeMoney/DesignSystem/SentenceHighlighter.swift WadeMoneyTests/SentenceHighlighterTests.swift
git commit -m "feat(report): add SentenceHighlighter number-classification logic"
```

---

## Task 2: SwiftUI 렌더링 확장 + AIReportScreen 통합

**Files:**
- Modify: `WadeMoney/DesignSystem/SentenceHighlighter.swift` (append SwiftUI extension)
- Modify: `WadeMoney/Screens/Report/AIReportScreen.swift:85-86` (summaryCard 문장), `:137-145` (tipCard 전체), `:16-27` (body 카드 렌더 분기 + 애니메이션)

**Interfaces:**
- Consumes: Task 1의 `SentenceHighlighter.spans(in:)`, `HighlightKind`, `HighlightSpan`; 기존 `WadeColors.bad/good/ink`, `WadeFont.pretendard`, `AIReportViewModel.Display`, `AIReportViewModel.isNarrating`.
- Produces: `SentenceHighlighter.styledText(_ text: String, font: Font, scheme: ColorScheme) -> Text`; `AIReportScreen.tipCard(_ tip: String, isPlaceholder: Bool = false) -> some View`.

- [ ] **Step 1: Append the SwiftUI styling extension to SentenceHighlighter.swift**

Add to the end of `WadeMoney/DesignSystem/SentenceHighlighter.swift`:

```swift
extension SentenceHighlighter {
    /// text를 강조 구간 기준으로 나눠 Text로 조합한다. 강조 구간은 굵게+kind별 색상,
    /// 나머지는 기본 잉크색을 적용해 기존 평문 Text와 같은 기본 톤을 유지한다.
    static func styledText(_ text: String, font: Font, scheme: ColorScheme) -> Text {
        let baseColor = WadeColors.ink(scheme)
        var result = Text("")
        var cursor = text.startIndex
        for span in spans(in: text) {
            if cursor < span.range.lowerBound {
                result = result + Text(text[cursor..<span.range.lowerBound]).font(font).foregroundStyle(baseColor)
            }
            result = result + Text(text[span.range])
                .font(font)
                .fontWeight(.bold)
                .foregroundStyle(highlightColor(for: span.kind, scheme: scheme))
            cursor = span.range.upperBound
        }
        if cursor < text.endIndex {
            result = result + Text(text[cursor...]).font(font).foregroundStyle(baseColor)
        }
        return result
    }

    private static func highlightColor(for kind: HighlightKind, scheme: ColorScheme) -> Color {
        switch kind {
        case .increase: return WadeColors.bad(scheme)
        case .decrease: return WadeColors.good(scheme)
        case .neutral: return WadeColors.ink(scheme)
        }
    }
}
```

- [ ] **Step 2: Replace the plain summary sentence Text with styledText**

In `WadeMoney/Screens/Report/AIReportScreen.swift`, find (inside `summaryCard`):

```swift
            Text(d.summarySentence ?? "이번 달 총지출은 \(d.totalText)원이에요.")
                .font(WadeFont.pretendard(14.5)).foregroundStyle(WadeColors.ink(scheme))
```

Replace with:

```swift
            SentenceHighlighter.styledText(
                d.summarySentence ?? "이번 달 총지출은 \(d.totalText)원이에요.",
                font: WadeFont.pretendard(14.5),
                scheme: scheme
            )
```

- [ ] **Step 3: Replace tipCard with a version that highlights numbers and supports a placeholder state**

Find:

```swift
    private func tipCard(_ tip: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Icon("lightbulb", size: 19).foregroundStyle(WadeColors.primary(scheme))
            Text(tip).font(WadeFont.pretendard(13.5)).foregroundStyle(WadeColors.ink(scheme))
        }
        .padding(WadeSpacing.cardPadding)
        .background(WadeColors.primarysoft(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.card, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
```

Replace with:

```swift
    private func tipCard(_ tip: String, isPlaceholder: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Icon("lightbulb", size: 19).foregroundStyle(WadeColors.primary(scheme))
            SentenceHighlighter.styledText(tip, font: WadeFont.pretendard(13.5), scheme: scheme)
        }
        .padding(WadeSpacing.cardPadding)
        .background(WadeColors.primarysoft(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.card, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
        .redacted(reason: isPlaceholder ? .placeholder : [])
    }
```

- [ ] **Step 4: Show a placeholder tip card while narrating, and animate the transition**

Find (inside `body`):

```swift
                if let vm = viewModel, let d = vm.display {
                    summaryCard(d, isNarrating: vm.isNarrating)
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
```

Replace with:

```swift
                if let vm = viewModel, let d = vm.display {
                    summaryCard(d, isNarrating: vm.isNarrating)
                    projectionCard(d)
                    if !d.changes.isEmpty { changesCard(d) }
                    if let tip = d.tipSentence {
                        tipCard(tip)
                    } else if vm.isNarrating {
                        tipCard("절약 팁을 준비하고 있어요…", isPlaceholder: true)
                    }
                    footerNote
                }
            }
            .padding(.horizontal, WadeSpacing.screenH)
            .padding(.top, WadeSpacing.contentTop)
            .padding(.bottom, WadeSpacing.contentBottom)
            .animation(.easeInOut(duration: 0.25), value: viewModel?.display?.tipSentence)
        }
```

- [ ] **Step 5: Build and run the full unit test suite to confirm no regressions**

Run: `xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests`
Expected: all tests pass (125 pre-existing + 8 new `SentenceHighlighterTests` = 133), including `AIReportViewModelTests` unchanged (its assertions target the plain `Display.summarySentence`/`tipSentence` strings, not the rendered `Text`, so they aren't affected by this task).

- [ ] **Step 6: Commit**

```bash
git add WadeMoney/DesignSystem/SentenceHighlighter.swift WadeMoney/Screens/Report/AIReportScreen.swift
git commit -m "feat(report): highlight numbers in AI sentences and add tip card loading skeleton"
```

---

## 최종 검증 (컨트롤러 담당, 서브에이전트 범위 아님)

두 태스크 모두 완료되고 리뷰가 끝나면, 이 항목은 플랜을 실행하는 컨트롤러(브레인스토밍·플랜 작성을 진행한 세션)가 직접 수행한다 — 온디바이스 AI(Foundation Models)가 시뮬레이터에서 동작하지 않아 실제 앱 흐름으로는 강조 렌더링을 재현할 수 없기 때문이다.

- `AIReportScreen.swift`의 `.task` 블록을 임시로 수정해 `viewModel`에 스펙의 목업 문장과 동일한 값("카페 지출이 지난달 같은 시점보다 32% 늘었고, 전체 지출도 9.7% 많아요." / "이번 주 카페를 2번만 줄여도 예산 안에 들어올 수 있어요.")을 가진 `Display`를 직접 주입한다.
- 로컬 빌드 후 iPhone 17e 시뮬레이터에 설치해 리포트 화면을 스크린샷으로 캡처, 다음을 육안 확인한다:
  - "32%"가 굵은 빨강/주황, "9.7%"가 굵은 검정(중립)으로 렌더링되는지
  - 라이트/다크 모드 양쪽에서 색상 대비가 충분한지
  - `tipCard(_:isPlaceholder: true)`가 `.redacted`로 스켈레톤처럼 보이는지 (isNarrating 강제 true로 별도 확인)
- 확인이 끝나면 `.task` 블록의 임시 주입 코드를 정확히 되돌리고 `git diff`가 비어 있는지 확인한 뒤, 검증용 임시 변경은 커밋하지 않는다.

## Self-Review 메모

- **스펙 커버리지**: 숫자 강조(스펙 §1) → Task 1+2. 팁 카드 로딩 스켈레톤(스펙 §2) → Task 2 Step 3-4. AI 진입점 게이트 불변 → Global Constraints에 명시, 코드 변경 없음. 차트/InsightCard 확장 제외 → Global Constraints에 명시.
- **플레이스홀더 스캔**: 없음 — 모든 스텝에 실행 가능한 전체 코드/커맨드 포함.
- **타입 일관성 확인**: Task 1이 정의한 `HighlightKind`/`HighlightSpan`/`SentenceHighlighter.spans(in:)` 시그니처가 Task 2의 `styledText`/`AIReportScreen` 사용 지점과 정확히 일치.
