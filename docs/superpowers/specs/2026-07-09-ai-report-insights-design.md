# AI 소비 리포트 인사이트 개선 — 설계 스펙

날짜: 2026-07-09
상태: 사용자 승인됨 (섹션별 구두 승인, 브레인스토밍 세션)

## 배경과 문제

현재 AI 리포트(AIReportScreen)는 구조적으로 건전하다 — 모든 수치는 Swift에서
결정적으로 계산되고 Foundation Models(온디바이스)는 문장 작성만 한다. 문제는
**모델에 주는 재료가 빈약**하다는 것: 총지출·예산상태·전월증감·예상지출 4가지뿐이라
"전월 대비 감소한 지출은 0%입니다" 같은 무의미한 문장과 뻔한 절약 팁이 나온다.

추가 문제 2가지:
1. **예상 지출 왜곡**: 단순 선형 외삽(누적 ÷ 경과일 × 전체일수)이라 월초 큰 지출
   하나가 달 전체로 곱해져 "예산 50만 대비 +342만 초과 예상" 같은 과장된 경고가 뜬다.
2. **카드 폭 버그**: `AIReportScreen`의 `card` 헬퍼와 `tipCard`가 `.background` 뒤에
   `.frame(maxWidth: .infinity)`를 적용해, 콘텐츠가 짧으면 카드 배경이 화면 폭을
   채우지 못한다.

## 목표

- 사용자의 소비 내역에서 **습관 발견형 + 예산 실행형** 인사이트를 결정적으로
  계산해 리포트에 노출한다 (외부 사례: 토스 주간 리포트, 뱅크샐러드 소비 분석,
  Copilot/Monarch의 패턴 인사이트).
- Foundation Models는 지금처럼 **주어진 수치만 인용해 작문**한다. 숫자
  계산/생성은 절대 모델에 맡기지 않는다 (온디바이스 소형 모델은 산술에 약함).
- 예상 지출을 일회성 지출 분리로 안정화하고, 월초에는 신뢰도 캡션을 붙인다.
- 리포트 카드 폭 버그를 고친다.

## 접근 (승인된 A안)

결정적 인사이트 엔진 + AI 내레이션. 엔진은 WadeMoneyCore의 순수 함수로 인사이트
후보를 계산하고 자격 규칙으로 필터링, 고정 우선순위로 최대 3개 선정. ViewModel이
텍스트로 포매팅해 카드로 노출하고, 같은 사실 문자열을 AI 프롬프트 재료로 넘긴다.

기각한 대안: (B) 모델에 집계 테이블을 주고 선택+작문 위임 — 숫자 환각 위험, 테스트
불가. (C) 엔진 계산 + 모델 선별 — 선택 규칙은 코드 몇 줄이면 충분, 지연만 증가.

## 컴포넌트 설계

### 1. InsightEngine (신규, WadeMoneyCore/Sources/WadeMoneyCore/InsightEngine.swift)

```swift
public enum Insight: Equatable, Sendable {
    case budgetRunway(exhaustDate: Date)
    case largestExpense(amount: Decimal, categoryID: UUID?, memo: String?, shareOfTotal: Decimal)
    case dailyAveragePace(currentDailyAverage: Decimal, deltaRatio: Decimal)
    case frequency(categoryID: UUID?, count: Int, total: Decimal, averagePerVisit: Decimal)
    case weekendConcentration(fraction: Decimal)
    case noSpendDays(count: Int)
}

public struct InsightEngine: Sendable {
    public init(calc: PeriodCalculator)
    /// txns: 이번 달+지난달을 덮는 거래 배열(리포트 VM이 이미 페치하는 범위).
    /// 자격을 통과한 인사이트를 위 enum 선언 순서(우선순위)로 최대 maxCount개 반환.
    public func insights(
        txns: [TransactionRecord],
        period: Period,          // 이번 달
        asOf now: Date,
        budget: Decimal?,        // 월 예산 (미설정이면 nil)
        maxCount: Int = 3
    ) -> [Insight]
}
```

원시 값(Decimal/Int/Date)만 반환하고 텍스트 포매팅은 앱 계층이 한다 —
Aggregator/PaceCalculator와 같은 패턴. "경과 구간"은 `period.start`부터
`daysElapsed`일까지 (PaceCalculator와 동일한 잘라내기 규칙).

자격 규칙 (모두 결정적, 경계 포함):

| 우선순위 | 인사이트 | 계산 | 자격 규칙 |
|---|---|---|---|
| 1 | budgetRunway | routineDailyAvg = (경과 구간 예산반영 지출 − 일회성) ÷ 경과일. daysUntilExhaust = ceil((budget − 예산반영 누적) ÷ routineDailyAvg). exhaustDate = startOfDay(now) + daysUntilExhaust일 | budget != nil && budget > 0, 남은 예산 > 0, routineDailyAvg > 0, exhaustDate < period.end |
| 2 | largestExpense | 경과 구간 지출 중 최대 1건. shareOfTotal = amount ÷ 경과 구간 총지출 | 지출 건수 ≥ 3, shareOfTotal ≥ 0.25 |
| 3 | dailyAveragePace | currentDailyAvg = 경과 구간 총지출 ÷ 경과일. 지난달 같은 경과일 구간 대비 deltaRatio (PaceCalculator 규칙과 동일: priorD = min(d, priorLength)) | 지난달 비교 구간 지출 > 0, abs(deltaRatio) ≥ 0.10 |
| 4 | frequency | 경과 구간 지출을 categoryID로 그룹, 건수 최다 카테고리(동수면 총액 큰 쪽). averagePerVisit = total ÷ count | count ≥ 5, categoryID != nil |
| 5 | weekendConcentration | fraction = 경과 구간 주말(calendar.isDateInWeekend) 지출 ÷ 경과 구간 총지출 | 경과일 ≥ 14, 총지출 > 0, fraction ≥ 0.5 |
| 6 | noSpendDays | 경과일 중 지출 거래가 0건인 날 수 | 경과일 ≥ 7, count ≥ 1 |

지출 범위: budgetRunway만 예산반영(budgeted) 지출 기준, 나머지는 전체 지출
(예산 제외 포함 — 습관 발견이 목적이므로). 일회성 정의는 Projection과 공유(아래).

### 2. Projection 안정화 (WadeMoneyCore/Sources/WadeMoneyCore/Projection.swift 수정)

```swift
public enum Projection {
    // 기존 projectedTotal은 유지 (다른 잠재 소비처와 테스트 보존)

    /// 일회성 지출을 분리한 안정화 예상치.
    /// 일회성 = 누적 합의 30% 이상을 단독으로 차지하는 지출 1건.
    /// 예상치 = 일회성 합 + (나머지 일상 지출 ÷ 경과일 × 전체일수).
    public static func stabilizedProjectedTotal(
        amounts: [Decimal],     // 경과 구간 예산반영 지출 개별 금액들
        daysElapsed: Int,
        daysInPeriod: Int
    ) -> Decimal
}
```

- `daysElapsed <= 0`이면 0 (기존 규칙 유지).
- total = amounts 합. total == 0이면 0.
- oneOffs = `amount >= total * 0.3`인 금액들 (경계 포함).
- projected = oneOffs 합 + (total − oneOffs 합) × daysInPeriod ÷ daysElapsed.
- 지출이 1건뿐이면 그 금액이 100% ≥ 30% → 일회성 → 예상치 = 그 금액 (의도된 동작).

`LedgerRepository.dashboardSummary`의 projected 계산을 이 함수로 교체
(month/year kind에서 예산반영 지출 개별 금액 배열을 넘긴다). 이 값의 소비처는
AIReportScreen뿐이다.

### 3. AIReportViewModel 확장

Display에 추가:

```swift
struct InsightCardItem: Equatable, Identifiable {
    let id: String        // insight kind 기반 안정 문자열 ("runway", "largest", ...)
    let iconName: String  // Material Symbols 이름
    let text: String      // 결정적 템플릿 문장
}
let insightCards: [InsightCardItem]   // 최대 3개
let projectionCaption: String?        // 월초 신뢰도 캡션
```

포매팅 규칙 (모두 존댓말, 수치는 Won.string):

| 인사이트 | 카드 문장 템플릿 | 아이콘 |
|---|---|---|
| budgetRunway | "이 속도면 {M월 d일}쯤 예산이 소진돼요" | hourglass_bottom |
| largestExpense | "가장 큰 지출은 {메모 또는 카테고리명} {금액}원 — 이번 달 지출의 {N}%예요" | payments |
| dailyAveragePace | "하루 평균 {금액}원 쓰고 있어요 — 지난달 같은 시점보다 {N}% {높아요/낮아요}" | trending_up / trending_down |
| frequency | "{카테고리명}에 {N}번 · 총 {금액}원 · 회당 평균 {금액}원" | repeat |
| weekendConcentration | "지출의 {N}%가 주말에 몰려 있어요" | weekend |
| noSpendDays | "이번 달 무지출일이 {N}일 있었어요" | event_available |

- largestExpense의 이름: memo가 비어 있지 않으면 memo, 아니면 카테고리명, 그것도
  없으면 "기타" (HistoryViewModel.row와 같은 규칙).
- projectionCaption: `daysElapsed / dayCount < 0.25`이고 projected가 있으면
  "아직 초반이라 예상치가 달라질 수 있어요", 아니면 nil.
- 인사이트 계산은 load()가 이미 페치한 거래 배열을 재사용 — 추가 DB 조회 없음.

### 4. AI 내레이션 개선 (AIServices.swift + FoundationModelsAIServices.swift)

ReportInput 변경:

```swift
struct ReportInput: Sendable {
    let monthLabel: String
    let daysElapsedText: String
    let totalExpenseText: String
    let budgetStatusText: String
    /// nil이면 프롬프트에서 전월 대비 줄 자체를 생략 (0%·비교불가 문장 차단).
    let paceDelta: (percentText: String, increased: Bool)?
    let projectedTotalText: String
    let topIncrease: (name: String, percentText: String)?
    let topDecrease: (name: String, percentText: String)?
    /// 선정된 인사이트의 결정적 사실 문자열 (카드 문장과 동일, 최대 3개).
    let insightFacts: [String]
}
```

- VM은 `deltaRatio`가 nil이거나 0이면 `paceDelta = nil`로 넘긴다.
- 프롬프트: insightFacts를 "주요 발견:" 목록으로 추가. 요약 문장은 총지출과 가장
  눈에 띄는 발견 1개를 엮도록, 팁 문장은 **주요 발견 중 하나에 근거한 구체적 행동**
  을 제안하도록 지시. 새 숫자 생성 금지 규칙 유지.
- paceDelta가 nil이면 "전월 대비:" 줄을 프롬프트에서 생략.
- ReportNarrationOutput의 @Guide 설명에 "주어진 발견 사실에 근거" 지시 추가.
- 내레이션 캐시 키에 insightFacts를 포함 (구분자 \u{1F} 유지).

### 5. AIReportScreen UI

카드 순서: 요약 → 예상 지출 → **이번 달 발견(신규)** → 지난달 대비 변화 → 팁.

- "이번 달 발견" 카드: 섹션 제목 + 인사이트 행 목록(아이콘 + 문장).
  `insightCards`가 비어 있으면 섹션 자체를 렌더하지 않는다.
- 예상 지출 카드: projectionCaption이 있으면 금액 아래 작은 회색 캡션으로 표시.
- **폭 버그 수정**: `card` 헬퍼와 `tipCard`에서
  `.frame(maxWidth: .infinity, alignment: .leading)`을 `.padding`/`.background`
  **앞**으로 이동 — 배경이 항상 화면 폭을 채운다. 신규 발견 카드도 같은 순서
  (frame → padding → background)로 작성.

## 실패 처리 / 저하 동작

- InsightEngine·Projection은 순수 함수 — 실패 경로 없음.
- AI 꺼짐(설정)·미지원 기기·타임아웃 시: 인사이트 카드/예상 지출/변화 카드는 전부
  결정적으로 표시되고, 요약은 기존 폴백 문장, 팁 카드는 숨김 (현행 2단계 로딩 유지).

## 테스트 전략 (TDD)

- `InsightEngineTests` (WadeMoneyCore/Tests, 신규 파일 — SwiftPM이라 xcodegen 불필요):
  후보 6종 각각의 자격 경계(4회 vs 5회, 24% vs 25%, 9% vs 10%, 13일 vs 14일 등),
  우선순위 순서, maxCount=3 상한, 예산 미설정 시 runway 제외.
- `ProjectionTests` 확장: 일회성 분리 계산값, 지출 1건뿐인 경우, 30% 경계,
  일회성 없는 경우 기존 선형과 동일.
- `AIReportViewModelTests` 확장: 인사이트 → 카드 텍스트/아이콘 매핑,
  projectionCaption 노출 조건(25% 경계), paceDelta nil 처리, 캐시 키에
  insightFacts 반영.
- 전체 단위 테스트: `xcodebuild test -scheme WadeMoney -destination
  'platform=iOS Simulator,name=iPhone 17e'` 통과. 신규 테스트 이름이 실제로
  실행됐는지 grep으로 확인 (stale bundle 함정 방지).

## 범위 밖 (이번 작업에서 하지 않음)

- 대시보드 인사이트 배너(InsightGenerating)의 입력 확장 — 리포트만 대상.
- 주간 리포트, 알림 연동, 인사이트 히스토리.
- History 화면 predicate 전환 등 기존 백로그.
