# Dashboard Trend Interaction + Category Detail Screens — Design

## Problem

1. **지출 추세 카드 금액 잘림**: `TrendCard`(`WadeMoney/Screens/Dashboard/DashboardComponents.swift`)는 현재 기간 막대 바로 위에 `bar.valueText`를 표시하는데, 6개 막대가 카드 폭을 나눠 갖는 좁은 컬럼 안에서는 7자리 이상 금액("1,393,200")이 줄바꿈 지점(공백) 없이 렌더링되어 시스템 기본 말줄임("1,393,2...")으로 잘린다.
2. **카테고리 비중 상세 부재**: 대시보드의 "카테고리 비중" 카드는 상위 6개 카테고리 + "기타" 버킷만 보여준다(`Donut.slices(..., maxSlices: 6)`). 각 카테고리의 실제 지출 내역을 더 자세히 파악할 방법이 없다.

## Non-Goals

- 대시보드 전체 선택 기간(offset)을 트렌드 카드 탭으로 바꾸지 않는다 — 트렌드 카드 안에서만 표시가 바뀐다.
- 카테고리 상세 화면에서 기간을 직접 바꾸는 컨트롤은 추가하지 않는다 — 진입 시점의 대시보드 기간을 그대로 사용한다.
- 카테고리별 트렌드(전월 대비 증감 등) 비교는 이번 스코프에 포함하지 않는다.
- `HistoryViewModel`을 재사용하거나 확장하지 않는다 — 검색/그룹핑이 필요 없는 단순 리스트라서 카테고리 상세 전용의 가벼운 뷰모델을 새로 만든다.

## 1. Trend Card Tap-to-Inspect

### Data (unchanged)

`DashboardViewModel.TrendBar` (id/label/valueText/heightFraction/isCurrent)는 그대로 사용한다. 데이터 소스나 계산 로직 변경 없음.

### `TrendCard` changes

- `@State private var selectedID: Int?` 추가. `nil`이면 "현재 기간 표시" 상태를 의미한다.
- `selectedBar`: `selectedID`가 있으면 해당 id의 bar, 없으면 `bars.first(where: \.isCurrent)`.
- 헤더 행: 기존 `Text("지출 추세")` 한 줄짜리 HStack에 `Spacer()` + 선택된 bar의 라벨과 금액을 우측 정렬로 추가. 형식: `"{selectedBar.label} · {selectedBar.valueText}"` (예: `4월 · ₩820,000`). `selectedBar`가 nil(막대가 아예 없는 빈 상태)이면 표시하지 않는다.
- 막대 위의 개별 `valueText` Text는 제거한다(잘림의 근본 원인이었던 요소).
- 각 막대(현재 `VStack` 컬럼)에 `.contentShape(Rectangle())` + `.onTapGesture { selectedID = bar.id }` 추가.
- 하이라이트: 기존에는 `bar.isCurrent`만 `WadeColors.primary`로 칠했다. 이제는 "선택된 막대"(`bar.id == selectedBar?.id`)를 `primary`로, 나머지는 `barmuted`로 칠한다. 라벨 텍스트 굵기도 동일한 기준(선택 여부)으로 전환한다.
- `.onChange(of: bars) { selectedID = nil }` 추가 — 일/월/년 전환이나 기간 이동(offset 변경)으로 `bars` 배열이 교체되면 선택을 초기화해 항상 새 데이터의 "현재 기간"으로 되돌아간다. (`TrendBar`는 이미 `Equatable`이라 배열 비교가 가능하다.)

### Verification

- 기존 `DashboardViewModelTests`는 변경 없음(데이터 계산 로직 불변).
- 시뮬레이터 스크린샷으로 확인: 기본 진입 시 현재 기간 금액이 헤더에 잘림 없이 보이는지, 과거 막대를 탭했을 때 헤더 값과 하이라이트가 바뀌는지, 일/월/년 전환 시 선택이 초기화되는지.

## 2. Category Breakdown + Detail Screens

### Data flow

`DashboardViewModel.DashboardDisplay`에 `let period: Period` 필드를 추가한다(WadeMoneyCore의 `Period` — `kind`/`start`/`end`, 이미 `Equatable & Sendable`). `buildDisplay`(또는 해당 매핑 함수) 안에서 이미 계산된 `s.period`를 그대로 담아 전달한다. 새 화면들은 이 `Period`를 그대로 받아 재사용하므로 month-start-day 등 기간 계산 로직을 중복하지 않는다.

### `CategoryBreakdownScreen` (1단계 — 전체 카테고리 순위)

- 진입: `DashboardScreen`에서 `DonutCard`를 감싸는 탭 제스처. `legend.isEmpty`(빈 상태)일 때는 탭 비활성화.
- `CategoryBreakdownViewModel(repository:period:periodLabel:)`:
  - `repository.transactions(from: period.start, to: period.end)` 조회 후 `Aggregator.totalsByCategory(txns, in: period)`로 전체(버킷 없이) 카테고리별 합계를 금액 내림차순으로 얻는다.
  - `repository.allCategories(includeArchived: true)`로 이름/아이콘/색상 매핑(보관된 카테고리라도 과거 지출 내역엔 등장할 수 있으므로 `includeArchived: true`).
  - `grandTotal = totals.reduce(0) { $0 + $1.total }`; 각 항목의 `percentText = "\(Int((total/grandTotal*100).rounded()))%"`.
  - Row: `id`, `name`, `iconName`, `colorHex`, `amountText`, `percentText`.
- 화면 구성: 타이틀 "{periodLabel} 카테고리별 지출", 각 행 탭 시 `CategoryDetailScreen`으로 이동(`NavigationLink` 또는 `navigationDestination(item:)`).

### `CategoryDetailScreen` (2단계 — 단일 카테고리 상세)

- 진입 파라미터: `category: CategoryRef`, `period: Period`, `periodLabel: String`, `repository: LedgerRepository`.
- `CategoryDetailViewModel`:
  - 동일하게 `repository.transactions(from: period.start, to: period.end)` 조회 후 `categoryID == category.id`인 지출 건만 필터링, 날짜 내림차순 정렬.
  - 요약: `total = 필터링된 거래 합계`, `percentText`는 1단계와 동일한 `grandTotal` 기준(같은 기간의 전체 카테고리 합계를 다시 계산)으로 산출.
  - 거래 행: 날짜/메모(없으면 카테고리명 등 기존 History 폴백과 동일 규칙) / 금액. `예산 제외`로 표시된 건은 History와 동일하게 인라인 라벨을 보여준다(기존 `showsBudgetExcludedLabel` 규칙 재사용 — 로직만 참고, 뷰모델 자체는 재사용하지 않음).
- 화면 구성: 상단 요약 카드("{periodLabel} {amountText} · 지출 {percentText}"), 그 아래 "최근 거래" 리스트.

### Files (expected)

- `WadeMoney/Screens/Dashboard/DashboardViewModel.swift` — `period` 필드 추가.
- `WadeMoney/Screens/Dashboard/DashboardComponents.swift` — `TrendCard` 탭 인터랙션.
- `WadeMoney/Screens/Dashboard/DashboardScreen.swift` — `DonutCard` 탭 → `CategoryBreakdownScreen` 네비게이션.
- `WadeMoney/Screens/Dashboard/CategoryBreakdownScreen.swift` (신규) + 뷰모델.
- `WadeMoney/Screens/Dashboard/CategoryDetailScreen.swift` (신규) + 뷰모델.
- 관련 테스트: `WadeMoneyTests/DashboardViewModelTests.swift`(period 필드), 신규 `CategoryBreakdownViewModelTests.swift`, `CategoryDetailViewModelTests.swift`.

### Verification

- 새 뷰모델들은 순수 계산 로직 위주라 유닛 테스트로 커버(정렬 순서, 퍼센트 계산, 카테고리 필터링, 빈 상태 없음 보장).
- 시뮬레이터 스크린샷으로 1단계 목록 → 2단계 상세 진입 흐름 확인, 다크/라이트 모드 확인.
