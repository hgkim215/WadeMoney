# WadeMoney — 리뷰 백로그 정리 Implementation Plan (interim)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 계획 2~4 최종 리뷰에서 쌓인 Minor 백로그 9개 중, 지금 처리 가능한 7개를 해소한다. 폰트 서브셋팅(별도 도구 필요)과 `try?` 에러 정책(계획 5 AI 도입과 직결)은 이 계획에서 제외하고 각각의 자리에 남겨둔다.

**Architecture:** 순수 리팩터(디자인 토큰·저장소 재사용·기간별 fetch)는 기존 동작을 보존하며, 회귀 테스트로 "결과가 바뀌지 않았음"을 증명한다. 새 기능이 아니므로 각 태스크는 "동작 동일성 확인 테스트 + 빌드/스크린샷"으로 검증한다.

**Tech Stack:** SwiftUI, SwiftData, `WadeMoneyCore`, Swift Testing, XcodeGen, iOS 26 시뮬레이터.

## Global Constraints

- **범위**: 아래 7개 항목만. 폰트 서브셋팅, `try?` 에러 정책 재설계는 포함하지 않는다.
- **동작 보존**: 이 계획의 모든 변경은 사용자에게 보이는 동작을 바꾸지 않는다(순수 리팩터/정리). 각 태스크는 "이전과 결과가 같다"를 증명하는 테스트를 포함한다.
- **빌드/테스트**(서명 없이): `xcodegen generate` → `xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`. "Test run with N tests ... passed" 라인으로 확인. SourceKit IDE의 "No such module" 류는 오류 아님.
- 시작 테스트 수: 56 (계획 4 종료 시점).
- `.build/`·`*.xcodeproj`·`DerivedData/` 추적 금지. 커밋은 태스크마다.

---

### Task 1: 디자인 토큰 정리 + 죽은 코드 제거

**대상 백로그**: onPrimary/white 토큰 부재(6곳 원시 `.white`), cornerRadius 리터럴 2종(11, 18 — 4곳), `PlaceholderScreen` 죽은 코드(`RootTabView.swift` — 어떤 탭 케이스도 참조하지 않음, 확인됨).

**Files:**
- Modify: `WadeMoney/DesignSystem/WadeColors.swift` (`onPrimary` 토큰 추가)
- Modify: `WadeMoney/DesignSystem/WadeMetrics.swift` (`WadeRadius.button`, `WadeRadius.smallTile` 추가)
- Modify: `WadeMoney/Screens/RootTabView.swift` (`.white`→`onPrimary`, `PlaceholderScreen` 삭제)
- Modify: `WadeMoney/Screens/QuickAdd/QuickAddSheet.swift` (`.white`→`onPrimary`, `cornerRadius: 18`→`WadeRadius.button`)
- Modify: `WadeMoney/Screens/Settings/BudgetSheet.swift` (`.white`→`onPrimary`, `cornerRadius: 18`→`WadeRadius.button`)
- Modify: `WadeMoney/Screens/Categories/CategoryEditSheet.swift` (`.white`→`onPrimary`)
- Modify: `WadeMoney/Screens/History/HistoryScreen.swift` (`.white`→`onPrimary`)
- Modify: `WadeMoney/Screens/Dashboard/DashboardComponents.swift` (`cornerRadius: 11`→`WadeRadius.smallTile`)
- Modify: `WadeMoney/Screens/Categories/CategoryManageScreen.swift` (`cornerRadius: 11`→`WadeRadius.smallTile`)
- Test: `WadeMoneyTests/DesignTokenTests.swift` (토큰 값 테스트 추가)

**Interfaces:**
- Produces: `WadeColors.onPrimary(_ scheme: ColorScheme) -> Color`(라이트/다크 모두 흰색 — 프라이머리/굿 배경 위 텍스트용), `WadeRadius.button: CGFloat = 18`, `WadeRadius.smallTile: CGFloat = 11`

- [ ] **Step 1: 토큰 값 테스트 추가(실패 확인용)**

`WadeMoneyTests/DesignTokenTests.swift`에 다음 테스트를 기존 `DesignTokenTests` struct 안에 추가:

```swift
    @Test func newRadiusAndOnPrimaryTokensExist() {
        #expect(WadeRadius.button == 18)
        #expect(WadeRadius.smallTile == 11)
        #expect(WadeColors.onPrimary(.light) == WadeColors.onPrimary(.dark))
    }
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ... CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
Expected: 컴파일 실패 — `WadeRadius.button`/`WadeRadius.smallTile`/`WadeColors.onPrimary` 없음.

- [ ] **Step 3: 토큰 추가**

`WadeMoney/DesignSystem/WadeMetrics.swift`의 `WadeRadius` enum에 추가:

```swift
    static let button: CGFloat = 18
    static let smallTile: CGFloat = 11
```

`WadeMoney/DesignSystem/WadeColors.swift`에 추가(다른 `static func` 옆에):

```swift
    /// primary/good 등 채워진 배경 위에 올라가는 텍스트·아이콘 색(라이트/다크 공통 흰색).
    static func onPrimary(_ s: ColorScheme) -> Color { .white }
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild test ...`
Expected: 새 테스트 PASS.

- [ ] **Step 5: 호출부 교체**

다음 6개 파일에서 `.foregroundStyle(.white)` 또는 삼항식의 `.white` 분기를 `WadeColors.onPrimary(scheme)`로 교체(각 파일에 이미 `@Environment(\.colorScheme) private var scheme`가 있음 — 없으면 추가):
- `WadeMoney/Screens/RootTabView.swift:62` — `Icon("add", size: 30).foregroundStyle(WadeColors.onPrimary(scheme))`
- `WadeMoney/Screens/Settings/BudgetSheet.swift:33` — `amount > 0 ? WadeColors.onPrimary(scheme) : WadeColors.ink3(scheme)`
- `WadeMoney/Screens/QuickAdd/QuickAddSheet.swift:73` — `vm.canSave ? WadeColors.onPrimary(scheme) : WadeColors.ink3(scheme)`
- `WadeMoney/Screens/QuickAdd/QuickAddSheet.swift:89` — `vm.type == t ? WadeColors.onPrimary(scheme) : WadeColors.ink2(scheme)`
- `WadeMoney/Screens/Categories/CategoryEditSheet.swift:66` — `canSave ? WadeColors.onPrimary(scheme) : WadeColors.ink3(scheme)`
- `WadeMoney/Screens/History/HistoryScreen.swift:27` — `chip.isSelected ? WadeColors.onPrimary(scheme) : WadeColors.ink2(scheme)`

그리고 cornerRadius 리터럴 4곳 교체:
- `WadeMoney/Screens/Settings/BudgetSheet.swift:36` — `cornerRadius: 18` → `cornerRadius: WadeRadius.button`
- `WadeMoney/Screens/QuickAdd/QuickAddSheet.swift:76` — `cornerRadius: 18` → `cornerRadius: WadeRadius.button`
- `WadeMoney/Screens/Dashboard/DashboardComponents.swift:28` — `cornerRadius: 11` → `cornerRadius: WadeRadius.smallTile`
- `WadeMoney/Screens/Categories/CategoryManageScreen.swift:72` — `cornerRadius: 11` → `cornerRadius: WadeRadius.smallTile`

- [ ] **Step 6: 죽은 코드 제거**

`WadeMoney/Screens/RootTabView.swift`에서 `PlaceholderScreen` struct 전체를 삭제한다(파일 끝부분, `struct PlaceholderScreen: View { ... }`). 삭제 전 `grep -rn "PlaceholderScreen" WadeMoney/`로 다른 참조가 없는지 재확인.

- [ ] **Step 7: 빌드 + 스크린샷 확인**

```bash
xcodegen generate
xcodebuild build -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```
빌드 성공 확인 후, 앱을 설치·실행해 빠른 입력 시트 스크린샷 1장(저장 버튼 흰 글자, 지출/수입 토글 흰 글자 확인 — 시각적으로 이전과 동일해야 함, 회귀 아님을 확인하는 목적).

- [ ] **Step 8: 전체 스위트 통과 + 커밋**

Run: `xcodebuild test ...` — 전체 GREEN(57 = 56 + 새 토큰 테스트 1개).
```bash
git add WadeMoney/DesignSystem WadeMoney/Screens/RootTabView.swift WadeMoney/Screens/QuickAdd/QuickAddSheet.swift WadeMoney/Screens/Settings/BudgetSheet.swift WadeMoney/Screens/Categories WadeMoney/Screens/History/HistoryScreen.swift WadeMoney/Screens/Dashboard/DashboardComponents.swift WadeMoneyTests/DesignTokenTests.swift
git commit -m "refactor(ui): add onPrimary/button/smallTile tokens, remove dead PlaceholderScreen"
```

---

### Task 2: 설정 저장소 읽기 경로 정리 (앱 시작 시 시드 + 저장소 재사용)

**대상 백로그**: 대시보드 첫 렌더가 읽기 경로에서 `AppSettingsModel`을 삽입(쓰기)하는 놀라운 부작용, `dashboardSummary` 호출마다 `SettingsStore`를 2번 새로 생성.

**Files:**
- Modify: `WadeMoney/WadeMoneyApp.swift` (앱 시작 시 설정 시드)
- Modify: `WadeMoney/Stores/LedgerRepository.swift` (`dashboardSummary`에서 `SettingsStore` 1회만 생성)
- Test: `WadeMoneyTests/SettingsWarmupTests.swift`

**Interfaces:**
- Consumes: 기존 `SettingsStore.settingsModel()`(변경 없음)
- Produces: 앱 시작 시 `AppSettingsModel` 싱글턴이 미리 존재하도록 보장(동작 변경 없음, 순서만 보장)

- [ ] **Step 1: 실패하는(현재 동작을 고정하는) 테스트 작성**

`WadeMoneyTests/SettingsWarmupTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
@testable import WadeMoney

@MainActor
struct SettingsWarmupTests {
    @Test func dashboardSummaryDoesNotDuplicateSettingsRowOnRepeatedCalls() throws {
        let container = try PersistenceController.makeInMemoryContainer()
        let ctx = container.mainContext
        try CategorySeeder.seedIfNeeded(ctx)
        // 앱 시작 시 하는 것처럼 설정을 미리 시드한다.
        _ = try SettingsStore(context: ctx).settingsModel()

        let repo = LedgerRepository(context: ctx)
        let cal = Calendar(identifier: .gregorian)
        _ = try repo.dashboardSummary(kind: .month, offset: 0, now: Date(timeIntervalSince1970: 1_800_000_000), calendar: cal)
        _ = try repo.dashboardSummary(kind: .month, offset: 0, now: Date(timeIntervalSince1970: 1_800_000_000), calendar: cal)

        let count = try ctx.fetchCount(FetchDescriptor<AppSettingsModel>())
        #expect(count == 1)
        _ = container
    }
}
```

- [ ] **Step 2: 테스트 실행(이미 통과해야 함 — 기존 fetch-or-create 로직이 이미 안전함을 확인)**

Run: `xcodebuild test ...`
Expected: PASS(이 테스트는 회귀 방지용 안전망이며, 현재도 통과해야 정상 — 만약 실패하면 fetch-or-create 로직에 숨은 결함이 있다는 뜻이니 STOP하고 보고).

- [ ] **Step 3: 앱 시작 시 설정 시드 추가**

`WadeMoney/WadeMoneyApp.swift`의 `init()`에서 `try? CategorySeeder.seedIfNeeded(resolved.mainContext)` 바로 다음 줄에 추가:

```swift
        try? _ = SettingsStore(context: resolved.mainContext).settingsModel()
```

(테스트 호스트 가드로 인메모리 분기하는 경로에는 영향 없음 — 프로덕션 컨테이너 확정 후 블록에만 추가.)

- [ ] **Step 4: `dashboardSummary`에서 `SettingsStore` 1회만 생성**

`WadeMoney/Stores/LedgerRepository.swift`의 `dashboardSummary(...)` 시작 부분을 수정:

```swift
    func dashboardSummary(
        kind: PeriodKind,
        offset: Int,
        now: Date,
        calendar: Calendar
    ) throws -> DashboardSummary {
        let settingsStore = SettingsStore(context: context)
        let settings = try settingsStore.settings()
        let calc = PeriodCalculator(calendar: calendar, monthStartDay: settings.monthStartDay)
        let period = calc.period(kind, offset: offset, from: now)

        let txns = try allTransactions()
        let total = Aggregator.totalExpense(txns, in: period)

        let book = try settingsStore.budgetBook()
```

(이후 로직은 그대로 — `book`을 계속 사용.)

- [ ] **Step 5: 전체 스위트 통과 + 커밋**

Run: `xcodebuild test ...` — 전체 GREEN(누적 58).
```bash
git add WadeMoney/WadeMoneyApp.swift WadeMoney/Stores/LedgerRepository.swift WadeMoneyTests/SettingsWarmupTests.swift
git commit -m "refactor(app): warm-seed settings at launch, reuse one SettingsStore per dashboard call"
```

---

### Task 3: 대시보드 조회를 기간별 fetch로 전환 (전체 내역 대신)

**대상 백로그**: `dashboardSummary`가 매번 `allTransactions()`(전체 내역)를 로드 — 위젯(계획 6)에서 자주 호출되면 비용이 커짐. **내역(HistoryScreen) 화면은 의도적으로 전체 기간을 보여주므로 그대로 둔다** — 이 태스크는 `dashboardSummary`에만 적용.

**Files:**
- Modify: `WadeMoney/Stores/LedgerRepository.swift` (`transactions(from:to:)` 추가, `dashboardSummary`에서 사용)
- Test: `WadeMoneyTests/PeriodScopedFetchTests.swift`

**Interfaces:**
- Produces: `func transactions(from start: Date, to end: Date) throws -> [TransactionRecord]` — `date >= start && date < end`(반열림) 조건의 SwiftData `#Predicate` fetch.
- `dashboardSummary`는 `allTransactions()` 대신, 페이스 계산에 필요한 "이전 기간 시작 ~ 현재 기간 끝"(월/연) 또는 "현재 기간만"(일)의 좁은 범위로 조회한다. **`PaceCalculator`·`Aggregator`·`Donut`·`Projection`은 이미 자체적으로 날짜 범위를 필터링**하므로, 필요한 범위를 포함하는 배열을 넘기기만 하면 결과는 동일하다.

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/PeriodScopedFetchTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct PeriodScopedFetchTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }
    func repo() throws -> (LedgerRepository, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        return (LedgerRepository(context: container.mainContext), container)
    }
    func catID(_ r: LedgerRepository, _ n: String) throws -> UUID {
        try r.allCategories(includeArchived: false).first { $0.name == n }!.id
    }

    @Test func transactionsFromToIsHalfOpenAndExcludesOutside() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비")
        try r.addTransaction(amount: 1000, type: .expense, categoryID: food, memo: nil, date: date(2024, 1, 1))   // 훨씬 과거, 범위 밖
        try r.addTransaction(amount: 2000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))   // 범위 안
        try r.addTransaction(amount: 3000, type: .expense, categoryID: food, memo: nil, date: date(2026, 8, 1))   // 범위 끝(제외, 반열림)
        let result = try r.transactions(from: date(2026, 7, 1), to: date(2026, 8, 1))
        #expect(result.map(\.amount) == [2000])
        _ = c
    }

    @Test func dashboardSummaryUnchangedWithFarPastNoiseData() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비")
        // 2년 전 잡음 데이터 — 기간별 fetch로 바뀌어도 결과에 영향 없어야 함.
        try r.addTransaction(amount: 999_999, type: .expense, categoryID: food, memo: nil, date: date(2024, 1, 1))
        try r.addTransaction(amount: 80_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 6, 5))   // 지난달(페이스 비교용)
        try r.addTransaction(amount: 100_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5)) // 이번달

        let s = try r.dashboardSummary(kind: .month, offset: 0, now: date(2026, 7, 15), calendar: utc)
        #expect(s.totalExpense == 100_000)          // 2년 전 잡음이 섞이지 않음
        #expect(s.pace?.priorCumulative == 80_000)  // 지난달 데이터는 페이스 계산에 포함됨
        _ = c
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ...`
Expected: 컴파일 실패 — `transactions(from:to:)` 없음. (두 번째 테스트는 `transactions(from:to:)` 도입 전에도 `allTransactions()` 기반으로는 이미 통과할 수 있음 — 핵심은 fetch 방식을 바꾼 뒤에도 계속 통과해야 한다는 것.)

- [ ] **Step 3: `transactions(from:to:)` 구현**

`WadeMoney/Stores/LedgerRepository.swift`에 추가:

```swift
    func transactions(from start: Date, to end: Date) throws -> [TransactionRecord] {
        try context.fetch(
            FetchDescriptor<TransactionModel>(predicate: #Predicate { $0.date >= start && $0.date < end })
        ).map { $0.toRecord() }
    }
```

- [ ] **Step 4: `dashboardSummary`에서 좁은 범위로 조회**

`dashboardSummary(...)`에서 `let txns = try allTransactions()` 줄을, 기간·이전기간을 계산한 뒤로 옮기고 다음으로 교체:

```swift
        let fetchStart: Date
        switch kind {
        case .day:
            fetchStart = period.start
        case .month, .year:
            fetchStart = calc.previous(period).start
        }
        let txns = try transactions(from: fetchStart, to: period.end)
```

(이 줄은 `let period = calc.period(kind, offset: offset, from: now)` 다음, `let total = Aggregator.totalExpense(txns, in: period)` 앞에 위치해야 한다.)

- [ ] **Step 5: 테스트 통과 확인**

Run: `xcodebuild test ...`
Expected: `PeriodScopedFetchTests` 2 tests PASS + 기존 `LedgerRepositoryTests`·`DashboardViewModelTests` 등 `dashboardSummary`를 쓰는 모든 테스트 계속 GREEN(결과가 바뀌지 않았음을 증명).

- [ ] **Step 6: 전체 스위트 통과 + 커밋**

Run: `xcodebuild test ...` — 전체 GREEN(누적 60).
```bash
git add WadeMoney/Stores/LedgerRepository.swift WadeMoneyTests/PeriodScopedFetchTests.swift
git commit -m "perf(app): fetch only the needed date range for dashboardSummary instead of all history"
```

---

### Task 4: 내역 화면 리포지토리 재사용 + 혼합일 합계 동작 고정

**대상 백로그**: `HistoryScreen`이 행 탭마다 새 `LedgerRepository`를 생성, 지출+수입이 같은 날 섞이면 합계가 지출만 표시(의도된 동작인지 문서화 필요).

**Files:**
- Modify: `WadeMoney/Screens/History/HistoryScreen.swift` (리포지토리 재사용)
- Modify: `WadeMoney/Screens/History/HistoryViewModel.swift` (주석 추가)
- Test: `WadeMoneyTests/HistoryViewModelTests.swift` (혼합일 동작 고정 테스트 추가)

**Interfaces:**
- 변경 없음(동작 보존) — `HistoryScreen`이 `onAppear`에서 만든 리포지토리를 `@State`로 보관해 재사용.

- [ ] **Step 1: 혼합일 동작을 고정하는 실패 테스트 작성**

`WadeMoneyTests/HistoryViewModelTests.swift`의 기존 `HistoryViewModelTests` struct 안에 추가:

```swift
    @Test func mixedExpenseAndIncomeDayShowsExpenseSumOnly() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비")
        try r.addTransaction(amount: 9000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 15, 12))
        try r.addTransaction(amount: 45000, type: .income, categoryID: nil, memo: "환급", date: date(2026, 7, 15, 14))
        let vm = HistoryViewModel(repository: r, now: date(2026, 7, 15, 20), calendar: utc)
        vm.load()
        // 지출+수입이 섞인 날은 지출 합계만 표시(수입은 개별 행에서만 확인). 의도된 동작.
        #expect(vm.groups[0].sumText == "−9,000")
        #expect(vm.groups[0].sumIsIncome == false)
        _ = c
    }
```

- [ ] **Step 2: 테스트 실행(현재 로직이 이미 이 동작을 하므로 즉시 통과해야 함)**

Run: `xcodebuild test ...`
Expected: PASS. (통과하지 않으면 `HistoryViewModel`의 `sumIsIncome` 로직이 문서화하려는 것과 다르게 동작한다는 뜻이니 STOP하고 보고 — 로직을 바꾸지 말고 보고할 것.)

- [ ] **Step 3: 의도 문서화 주석 추가**

`WadeMoney/Screens/History/HistoryViewModel.swift`의 `sumIsIncome` 계산 줄 바로 위에 한 줄 주석 추가:

```swift
            // 지출+수입이 섞인 날은 지출 합계만 표시한다(순수 수입만 있는 날에만 +표시). 의도된 동작.
            let sumIsIncome = expense == 0 && income > 0
```

- [ ] **Step 4: `HistoryScreen`에서 리포지토리 재사용**

`WadeMoney/Screens/History/HistoryScreen.swift`에 `@State private var repository: LedgerRepository?`를 추가하고, `onAppear`에서 `viewModel` 생성 시 쓰는 리포지토리를 이 프로퍼티에 저장한 뒤, `recordFor(_:)`가 그 저장된 인스턴스를 사용하도록 바꾼다:

```swift
struct HistoryScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HistoryViewModel?
    @State private var repository: LedgerRepository?
    @State private var editingRecord: TransactionRecord?
    let refreshToken: Int

    // body는 기존과 동일하되, onAppear를 다음으로 교체:
    //   .onAppear {
    //       if viewModel == nil {
    //           let repo = LedgerRepository(context: modelContext)
    //           repository = repo
    //           let vm = HistoryViewModel(repository: repo, now: Date(), calendar: .current)
    //           vm.load(); viewModel = vm
    //       }
    //   }

    private func recordFor(_ id: UUID) throws -> TransactionRecord? {
        try repository?.transactionRecord(id: id)
    }
}
```

(다른 프로퍼티·메서드·뷰 빌더는 그대로 유지 — `onAppear`와 `recordFor(_:)`만 교체.)

- [ ] **Step 5: 빌드 + 회귀 없음 확인**

```bash
xcodegen generate
xcodebuild build -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```
빌드 성공 확인. (행 탭 → 편집 시트 열림은 기존 동작과 동일해야 하므로 별도 스크린샷 없이 빌드 성공 + 기존 `QuickAddEditTests` 통과로 충분.)

- [ ] **Step 6: 전체 스위트 통과 + 커밋**

Run: `xcodebuild test ...` — 전체 GREEN(누적 61).
```bash
git add WadeMoney/Screens/History
git commit -m "refactor(ui): reuse LedgerRepository in HistoryScreen, document mixed-day sum behavior"
```

---

## Self-Review (계획 작성자 확인 완료)

- **스펙 커버리지**: 계획 2/3/4 백로그 9개 중 7개 해소 — Task 1(토큰·죽은코드), Task 2(설정 읽기경로·저장소 재사용), Task 3(기간별 fetch), Task 4(리포지토리 재사용·혼합일 문서화). **제외 2개**: 폰트 서브셋팅(별도 폰트 도구 필요, 별도 작업으로 분리), `try?` 에러 정책(계획 5 AI에서 에러 표면화 방식을 함께 정할 때 다룸).
- **동작 보존 원칙**: 모든 태스크가 "이전과 결과 동일"을 테스트로 증명(Task 2·3·4의 Step 2는 회귀 방지 안전망 성격 — 실패 시 로직 결함이 이미 있었다는 뜻이므로 STOP 지시 포함).
- **플레이스홀더 스캔**: 없음. 모든 스텝에 실제 코드/명령 포함.
- **타입 일관성**: `WadeColors.onPrimary`·`WadeRadius.button`·`WadeRadius.smallTile`(Task 1)이 Task 1 내에서만 소비. `LedgerRepository.transactions(from:to:)`(Task 3)가 `dashboardSummary` 내부에서만 사용, 기존 `transactions(filter:)`·`allTransactions()` API는 변경 없음(내역 화면은 계속 전체 기간).

## 다음 계획으로의 인터페이스

이 정리 후 계획 5(AI)로 진행한다. 남은 백로그(폰트 서브셋팅, `try?` 정책)는 계획 5에서 에러 표면화 방식을 정할 때, 그리고 앱 용량이 문제될 때 각각 다룬다.
