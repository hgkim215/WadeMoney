# AI 리포트 화면 시각적 완성도 개선 — 설계 스펙

Date: 2026-07-03
Status: Approved (브레인스토밍 완료, 구현 계획 대기)

## 배경 / 문제

사용자가 목표로 제시한 목업(디테일한 7월 소비 리포트 화면)과 현재 `AIReportScreen`을 대조한 결과, 카드 구조(요약/예상 지출/변화/팁)는 이미 목업과 거의 동일하게 구현되어 있음을 확인했다. 실제 격차는 두 가지다:

1. 목업은 AI가 생성한 요약·팁 문장 안의 숫자(`32%`, `9.7%` 등)를 굵게+색깔로 강조해 "디테일하게 잘 표현된" 인상을 준다. 현재 `AIReportScreen`은 AI 문장을 통짜 평문 `Text`로만 렌더링해 숫자가 문장에 묻힌다.
2. AI가 문장을 생성하는 짧은 로딩 구간(`isNarrating == true`) 동안 팁 카드가 화면에 아예 존재하지 않다가, 생성이 끝나면 갑자기 나타나 레이아웃이 덜컹거린다.

브레인스토밍 과정에서 별도로 확인한 사항 — **작업 범위 아님**: 대시보드(한눈에) 화면의 AI 인사이트 블록(`InsightCard`)과 AI 리포트 진입 버튼은 이미 `aiAvailability.isAvailable && aiEnabled`로 게이트되어 있어, AI를 못 쓰는 기종/설정에서는 관련 UI가 전혀 노출되지 않는다(`DashboardViewModel.showsAIReportEntry`, `DashboardViewModel.refreshInsight()`). 이 로직은 이미 올바르므로 변경하지 않는다.

## 목표

- AI가 생성한 요약·팁 문장, 그리고 AI 문장이 아직 없을 때 보이는 결정적 대체 문장 안의 숫자(백분율·원화 금액)를 자동으로 굵게+색깔 강조해, AI 프롬프트나 스키마 변경 없이 목업 수준의 디테일한 인상을 준다.
- AI 문장 생성 대기 중에도 팁 카드 자리가 미리 잡혀 있어 레이아웃이 덜컹거리지 않도록 한다.

## 비목표 (이번 스코프에서 제외)

- 차트·그래프 등 목업에 없는 신규 시각 요소 추가.
- 대시보드 `InsightCard`(홈 화면 인사이트 문장)에 숫자 강조 적용 — 강조 로직은 재사용 가능한 독립 파일로 만들어 두지만, 이번 스코프에서 `InsightCard`에 실제로 연결하지는 않는다.
- AI 진입점 게이트 로직 변경 — 이미 올바르게 구현되어 있음을 확인했을 뿐, 코드 변경 없음.
- `ReportNarrationOutput` 등 AI 응답 스키마 변경 — 강조는 순수 클라이언트측 문자열 후처리로만 수행한다.

## 결정한 접근법

AI가 구조화된 강조 정보를 직접 내려주는 방식(스키마에 필드 추가)은 프롬프트·스키마 변경이 필요하고 온디바이스 LLM이 지시를 정확히 안 따를 리스크가 있어 제외했다.

**채택**: AI 문장(및 대체 문장)을 그대로 두고, 화면에 그리는 시점에 클라이언트측 정규식으로 숫자 패턴을 찾아 `AttributedString`/`Text` 조합으로 굵게+색깔 강조한다. 탐지·분류 로직은 SwiftUI에 의존하지 않는 순수 함수로 분리해 유닛 테스트 가능하게 만들고, 색상 매핑만 View 레이어에서 수행한다.

## 컴포넌트 구조

### `SentenceHighlighter` (신규, `WadeMoney/DesignSystem/SentenceHighlighter.swift`)

순수 로직. SwiftUI/Color에 의존하지 않아 UI 없이 테스트 가능하다.

```swift
enum HighlightKind: Equatable { case increase, decrease, neutral }

struct HighlightSpan: Equatable {
    let range: Range<String.Index>
    let kind: HighlightKind
}

enum SentenceHighlighter {
    static func spans(in text: String) -> [HighlightSpan]
}
```

**탐지 패턴** (정규식):
- 백분율: `\d+(\.\d+)?%` (예: `32%`, `9.7%`)
- 원화 금액: `[\d,]+원` (예: `110,000원`, `541,000원`)

두 패턴은 접미사(`%` vs `원`)가 달라 서로 겹치지 않는다. 매치를 시작 위치 기준으로 정렬해 `HighlightSpan` 목록을 만든다.

**방향 분류 (`HighlightKind` 결정)**: 각 매치의 끝 위치부터, 원문에서 다음으로 나오는 `,` 또는 `.` (없으면 문자열 끝)까지를 "같은 절(clause)"로 보고, 그 구간 안에서 키워드를 찾는다.
- `늘었`, `증가`, `올랐`, `초과` 중 하나라도 있으면 → `.increase`
- `줄었`, `감소`, `내렸`, `절약` 중 하나라도 있으면 → `.decrease` (증가 키워드가 이미 매치되었으면 증가 우선)
- 둘 다 없으면 → `.neutral`

예시: `"카페 지출이 지난달 같은 시점보다 32% 늘었고, 전체 지출도 9.7% 많아요."`
- `32%`의 절은 `"32% 늘었고"` (다음 쉼표까지) → `늘었` 포함 → `.increase`
- `9.7%`의 절은 `"9.7% 많아요."` (문자열 끝까지) → 키워드 없음 → `.neutral`

### `SentenceHighlighter+Text` (신규, 같은 파일 또는 `WadeMoney/DesignSystem/SentenceHighlighter+SwiftUI.swift`)

View 레이어 전용 확장. `spans(in:)` 결과를 순회하며 일반 구간은 그대로, 강조 구간은 `.fontWeight(.bold)` + 색상을 입혀 `Text`를 이어붙인다(`+` 연산자로 세그먼트별 스타일 유지).

```swift
extension SentenceHighlighter {
    static func styledText(_ text: String, font: Font, scheme: ColorScheme) -> Text
}
```

색상 매핑: `.increase` → `WadeColors.bad(scheme)`, `.decrease` → `WadeColors.good(scheme)`, `.neutral` → `WadeColors.ink(scheme)`. 강조 구간은 모두 `.fontWeight(.bold)`를 추가로 적용하고, 비강조 구간은 전달받은 `font`의 원래 굵기를 유지한다.

### `AIReportScreen` 수정 (`WadeMoney/Screens/Report/AIReportScreen.swift`)

- `summaryCard`: `Text(d.summarySentence ?? "이번 달 총지출은 \(d.totalText)원이에요.")` → `SentenceHighlighter.styledText(...)` 호출로 교체. AI 문장이든 결정적 대체 문장이든 동일하게 강조를 거친다.
- `tipCard`: 실제 문장을 그릴 때도 동일하게 `styledText`를 사용한다.
- `tipCard`에 `isPlaceholder: Bool = false` 파라미터 추가. `true`면 카드 전체에 `.redacted(reason: .placeholder)`를 적용해 스켈레톤처럼 보이게 한다(강조 없이 플레이스홀더 문구만 표시).
- 카드 렌더 분기:
  ```swift
  if let tip = d.tipSentence {
      tipCard(tip)
  } else if vm.isNarrating {
      tipCard("절약 팁을 준비하고 있어요…", isPlaceholder: true)
  }
  ```
- 플레이스홀더 → 실제 문장 전환에 짧은 크로스페이드(`.animation(.easeInOut(duration: 0.25), value: d.tipSentence)`)를 적용해 급작스러운 레이아웃 점프를 완화한다.

## 검증 계획

- `SentenceHighlighter.spans(in:)`에 대한 순수 유닛 테스트(`WadeMoneyTests/SentenceHighlighterTests.swift`): 증가 키워드 인접 케이스, 감소 키워드 인접 케이스, 키워드 없는 중립 케이스, 원화 금액 패턴, 한 문장에 매치 2개 이상(절 경계로 서로의 분류에 영향 안 주는지), 숫자 없는 문장(빈 배열), 쉼표로 분리된 절 경계 확인.
- 기존 `AIReportViewModelTests`는 `Display.summarySentence`/`tipSentence`가 여전히 순수 문자열이라는 계약을 검증하므로(강조는 View 레이어에서만 일어남) 변경 없이 계속 통과해야 한다.
- 나머지는 시각적 결과이므로 iPhone 17e 시뮬레이터에서 스크린샷으로 육안 확인: 증가/감소/중립 숫자 강조 색상, 팁 카드 로딩 스켈레톤 → 실제 문장 전환. AI가 시뮬레이터에서 동작하지 않을 가능성이 높으므로, `AIReportScreen`에 임시 프리뷰(mock `Display` 데이터, 목업과 동일한 문구)를 추가해 강조 렌더링을 직접 확인한다.
- 기존 유닛 테스트(현재 125개)가 계속 통과해야 한다.
