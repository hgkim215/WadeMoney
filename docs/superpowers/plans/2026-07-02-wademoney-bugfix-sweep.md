# WadeMoney — 버그 수정 스윕 Implementation Plan (interim)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 사용자가 실기기 테스트 중 발견한 5가지 기본 이슈를 고친다 — (1) 카테고리 시드 중복(계획 2 때부터의 TODO), (2) 설정 화면의 "월 시작일" 행이 죽어있는 UI(CRUD 갭), (3) 지출이 없을 때 대시보드 카테고리 비중 카드가 빈 링도 없이 이상하게 보이는 문제, (4) 빠른입력/예산/카테고리 편집 바텀시트에 스와이프 외에 명시적으로 닫을 방법이 없는 문제, (5) 작은 화면에서 콘텐츠가 잘리거나 그리드가 넘칠 수 있는 레이아웃 문제. 사전 조사(Explore 에이전트)로 각 이슈의 정확한 원인 파일:줄을 특정한 뒤 이 계획을 작성했다.

**Architecture:** 기존 계층(뷰모델/스토어는 테스트, 순수 SwiftUI 뷰는 빌드+선택적 스크린샷으로 검증)을 그대로 따른다. 태스크 1은 SwiftData 스키마에 필드 하나를 추가하는 유일하게 "로직" 있는 수정이라 TDD로 검증하고, 나머지는 UI 배선/레이아웃 수정이라 뷰모델 쪽만 있으면 테스트하고 순수 뷰 변경은 빌드 성공 검증으로 충분하다.

**Tech Stack:** SwiftUI, SwiftData, `@Observable`, Swift Testing, XcodeGen, iOS 26 시뮬레이터.

## Global Constraints

- **범위**: 아래 5개 이슈만. 조사에서 발견됐지만 이 계획에 포함하지 않는 항목(사소한 매직 넘버 정리, 아이콘 타일 반응형화 등)은 건드리지 않는다 — 실제 레이아웃 붕괴 위험이 있는 것만 고친다.
- **소프트 삭제 원칙 유지**: 카테고리 시드 중복 수정에서 기존 중복 카테고리를 자동으로 병합/삭제하지 않는다(이미 사용자가 쓰고 있을 수 있는 데이터를 잘못된 휴리스틱으로 보관 처리하는 위험을 피함) — 이 계획은 **향후 중복 방지**만 다룬다. 이미 생긴 중복은 카테고리 관리 화면의 기존 "보관하기" 기능으로 수동 정리 가능(이미 지원됨).
- **CloudKit 안전성**: `AppSettingsModel`에 추가하는 새 필드는 기본값이 있어야 하고(CloudKit 요구사항), `@Attribute(.unique)` 금지 — 기존 프로젝트 컨벤션 그대로.
- **바텀시트 닫기 버튼**: 각 시트의 기존 커스텀 헤더 패턴(시스템 `.toolbar`가 아니라 직접 그린 `HStack` 헤더)을 그대로 따른다 — 이 앱은 지금까지 모든 화면에서 커스텀 헤더를 써왔다(예: AI 리포트 화면의 "‹ 대시보드" 뒤로가기).
- **빌드/테스트**(서명 없이): `xcodegen generate` → `xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`. "Test run with N tests ... passed" 라인으로 확인. SourceKit IDE의 "No such module" 류는 오류 아님.
- SwiftData 테스트 헬퍼는 반드시 `ModelContainer`를 보유(미보유 시 dealloc 크래시).
- `.build/`·`*.xcodeproj`·`DerivedData/` 추적 금지. 커밋은 자주.
- 시작 테스트 수: 93 (계획 6 종료 시점). 각 태스크가 누적 증가.

---

### Task 1: 카테고리 시드 중복 방지

**문제(조사 결과)**: `CategorySeeder.seedIfNeeded`는 로컬 `CategoryModel` 카운트가 0이면 무조건 8종을 시드한다. CloudKit 최초 동기화는 비동기라 `WadeMoneyApp.init()` 시점엔 아직 안 끝났을 수 있다 — 기기 A가 이미 8종을 시드해 CloudKit에 올렸어도, 기기 B(또는 로컬 데이터 리셋 후 같은 기기)는 "로컬에 0개"로 보고 자신만의 8종을 또 시드한다. 동기화 완료 후 두 세트가 합쳐져 16개(카테고리마다 2배)가 된다.

**Files:**
- Modify: `WadeMoney/Models/AppSettingsModel.swift`
- Modify: `WadeMoney/Persistence/CategorySeeder.swift`
- Test: `WadeMoneyTests/CategorySeederTests.swift`

**Interfaces:**
- `AppSettingsModel`에 `var didSeedDefaultCategories: Bool = false` 추가(CloudKit 안전: 기본값 있음), `init`에도 파라미터 추가.
- `CategorySeeder.seedIfNeeded(_ context: ModelContext) throws` 시그니처는 동일하게 유지하되, 로컬 카운트가 아니라 `AppSettingsModel.didSeedDefaultCategories` 플래그를 1차 판단 기준으로 쓴다. 이 플래그는 다른 필드들과 함께 CloudKit으로 동기화되므로, 카테고리 8종 자체가 아직 로컬에 안 내려왔어도 "이미 어디선가 시드됐다"는 사실은 (그 레코드가 먼저 동기화되면) 더 빨리 알 수 있어 경쟁 창을 좁힌다.

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/CategorySeederTests.swift`에 추가(기존 3개 테스트는 그대로 둔다 — 새 로직과 여전히 호환됨):

```swift
extension CategorySeederTests {
    @Test func doesNotReseedWhenFlagAlreadySetEvenIfLocalStoreEmpty() throws {
        let c = try ctx()
        c.insert(AppSettingsModel(didSeedDefaultCategories: true))
        try c.save()
        try CategorySeeder.seedIfNeeded(c)
        let count = try c.fetchCount(FetchDescriptor<CategoryModel>())
        #expect(count == 0)   // 다른 기기가 이미 시드했고 플래그가 먼저 동기화됐다고 가정 — 로컬에서 또 시드하지 않음
    }

    @Test func backfillsFlagWhenCategoriesAlreadyExistWithoutFlag() throws {
        let c = try ctx()
        c.insert(CategoryModel(name: "커스텀", iconName: "category", colorHex: "#000000", sortOrder: 0))
        try c.save()
        try CategorySeeder.seedIfNeeded(c)
        let count = try c.fetchCount(FetchDescriptor<CategoryModel>())
        #expect(count == 1)   // 기존 카테고리 위에 기본 8종을 추가로 시드하지 않음(구버전 사용자 마이그레이션 케이스)
        let settings = try c.fetch(FetchDescriptor<AppSettingsModel>()).first
        #expect(settings?.didSeedDefaultCategories == true)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ...`. `AppSettingsModel(didSeedDefaultCategories:)` 초기화 파라미터 미정의로 컴파일 실패해야 한다.

- [ ] **Step 3: 구현**

`AppSettingsModel.swift` 전체 교체:

```swift
import Foundation
import SwiftData

@Model
final class AppSettingsModel {
    var id: UUID = UUID()
    var monthStartDay: Int = 1
    var aiEnabled: Bool = true
    var didSeedDefaultCategories: Bool = false

    init(
        id: UUID = UUID(),
        monthStartDay: Int = 1,
        aiEnabled: Bool = true,
        didSeedDefaultCategories: Bool = false
    ) {
        self.id = id
        self.monthStartDay = monthStartDay
        self.aiEnabled = aiEnabled
        self.didSeedDefaultCategories = didSeedDefaultCategories
    }
}
```

`CategorySeeder.swift`의 `seedIfNeeded`를 교체하고 헬퍼를 추가(`defaults` 배열과 `SeedCategory` 구조체, 파일 상단 주석은 그대로 둔다):

```swift
@MainActor
enum CategorySeeder {
    // ... 기존 defaults 배열/주석 그대로 ...

    /// 카테고리가 하나도 없을 때만 기본 8종을 삽입한다(멱등).
    /// AppSettingsModel.didSeedDefaultCategories 플래그가 CloudKit으로 동기화되므로,
    /// 다른 기기가 이미 시드했다면(플래그가 먼저 내려온 경우) 로컬에 카테고리가 아직
    /// 안 보여도 재시드하지 않는다 — 최초 동기화 완료 전 중복 시드 경쟁을 완화한다.
    static func seedIfNeeded(_ context: ModelContext) throws {
        let settings = try fetchOrCreateSettings(context)
        guard !settings.didSeedDefaultCategories else { return }

        let existing = try context.fetchCount(FetchDescriptor<CategoryModel>())
        if existing == 0 {
            for (index, seed) in defaults.enumerated() {
                context.insert(CategoryModel(
                    name: seed.name,
                    iconName: seed.iconName,
                    colorHex: seed.colorHex,
                    sortOrder: index
                ))
            }
        }
        // existing > 0인데 플래그가 없는 경우(구버전에서 이미 시드된 사용자) — 시드하지 않고 플래그만 세운다.
        settings.didSeedDefaultCategories = true
        try context.save()
    }

    private static func fetchOrCreateSettings(_ context: ModelContext) throws -> AppSettingsModel {
        if let existing = try context.fetch(FetchDescriptor<AppSettingsModel>()).first {
            return existing
        }
        let created = AppSettingsModel()
        context.insert(created)
        return created
    }
}
```

`CategorySeeder`가 `@MainActor`가 되므로, 기존 호출부(`WadeMoney/WadeMoneyApp.swift`의 `try? CategorySeeder.seedIfNeeded(resolved.mainContext)`, 이미 `@MainActor`인 `SettingsStore(...).settingsModel()`을 같은 자리에서 호출하고 있음)는 그대로 컴파일된다 — `WadeMoneyApp.swift`는 수정할 필요 없다.

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodegen generate && xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`. "Test run with 95 tests ... passed"(93 + 신규 2개) 확인. 기존 `seedsEightDefaultsOnEmptyStore`/`seedingIsIdempotent`/`firstCategoryMatchesDesignSpec` 3개도 여전히 통과해야 한다.

- [ ] **Step 5: 커밋**

```
git add WadeMoney/Models/AppSettingsModel.swift WadeMoney/Persistence/CategorySeeder.swift WadeMoneyTests/CategorySeederTests.swift
git commit -m "fix(data): guard category seeding with a synced flag to prevent cross-device duplication"
```

---

### Task 2: "월 시작일" 설정 화면 연결 (CRUD 갭 수정)

**문제(조사 결과)**: `SettingsStore.setMonthStartDay(_:)`는 이미 존재하고 테스트도 있지만(`SettingsWriteTests.swift`), `SettingsScreen`의 "월 시작일" 행은 `action: nil`로 만들어져 있어 탭해도 아무 일도 안 일어나는 죽은 UI다. 실제 시트가 한 번도 구현된 적이 없다.

**Files:**
- Modify: `WadeMoney/Screens/Settings/SettingsViewModel.swift`
- Modify: `WadeMoney/Screens/Settings/SettingsScreen.swift`
- Create: `WadeMoney/Screens/Settings/MonthStartDaySheet.swift`
- Test: `WadeMoneyTests/SettingsViewModelTests.swift`

**Interfaces:**
- `SettingsViewModel`에 `private(set) var monthStartDay: Int = 1` 추가(현재 `monthStartDayText`만 있음), `func setMonthStartDay(_ day: Int)` 추가.

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/SettingsViewModelTests.swift`에 추가:

```swift
extension SettingsViewModelTests {
    @Test func setMonthStartDayPersistsAndReloadsText() throws {
        let (vm, c) = try vm()
        vm.load()
        vm.setMonthStartDay(15)
        #expect(vm.monthStartDay == 15)
        #expect(vm.monthStartDayText == "매월 15일")
        _ = c
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ...`. `vm.monthStartDay`/`vm.setMonthStartDay` 미정의로 컴파일 실패해야 한다.

- [ ] **Step 3: 구현**

`SettingsViewModel.swift` 수정:

```swift
private(set) var budget: Decimal = 0
private(set) var budgetText: String = "0"
private(set) var monthStartDay: Int = 1
private(set) var monthStartDayText: String = "매월 1일"
private(set) var aiEnabled: Bool = true
private(set) var categoryCountText: String = "0개"

...

func load() {
    let settings = (try? settingsStore.settings()) ?? EngineSettings()
    aiEnabled = settings.aiEnabled
    monthStartDay = settings.monthStartDay
    monthStartDayText = "매월 \(settings.monthStartDay)일"
    let book = try? settingsStore.budgetBook()
    let amount = book?.amount(for: currentYearMonth) ?? 0
    budget = amount
    budgetText = Won.string(amount)
    let count = (try? categoryStore.active().count) ?? 0
    categoryCountText = "\(count)개"
}

func setBudget(_ amount: Decimal) {
    try? settingsStore.setMonthlyBudget(amount, for: currentYearMonth)
    load()
}

func setMonthStartDay(_ day: Int) {
    try? settingsStore.setMonthStartDay(day)
    load()
}

func toggleAI() {
    try? settingsStore.setAIEnabled(!aiEnabled)
    load()
}
```

`WadeMoney/Screens/Settings/MonthStartDaySheet.swift`(신규, `BudgetSheet.swift`와 같은 스타일):

```swift
import SwiftUI

struct MonthStartDaySheet: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Int
    let onSave: (Int) -> Void

    init(current: Int, onSave: @escaping (Int) -> Void) {
        _selected = State(initialValue: current)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("월 시작일").font(WadeFont.pretendard(20, weight: .heavy))
                Spacer()
                Button { dismiss() } label: {
                    Icon("close", size: 20).foregroundStyle(WadeColors.ink2(scheme))
                }.buttonStyle(.plain)
            }
            .padding(.top, 16)

            Text("지출 집계가 시작되는 매달의 기준일이에요").font(WadeFont.pretendard(12.5)).foregroundStyle(WadeColors.ink3(scheme))

            Picker("월 시작일", selection: $selected) {
                ForEach(1...28, id: \.self) { day in
                    Text("매월 \(day)일").tag(day)
                }
            }
            .pickerStyle(.wheel)

            Button {
                onSave(selected); dismiss()
            } label: {
                Text("저장").font(WadeFont.pretendard(17, weight: .heavy))
                    .foregroundStyle(WadeColors.onPrimary(scheme))
                    .frame(maxWidth: .infinity).padding(17)
                    .background(WadeColors.primary(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.button, style: .continuous))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 20).padding(.bottom, 30)
        .presentationDetents([.medium])
        .background(WadeColors.sheet(scheme))
    }
}
```

`SettingsScreen.swift` 수정 — `@State private var showBudget = false` 근처에 상태 추가, 행에 액션 연결, 시트 추가:

```swift
@State private var showBudget = false
@State private var showMonthStartDay = false
@State private var showCategories = false
```

```swift
row(icon: "event", tint: WadeColors.ink2(scheme), label: "월 시작일", trailing: vm.monthStartDayText) { showMonthStartDay = true }
```
(기존 `row(icon: "event", ..., action: nil)` 줄을 교체 — 마지막 인자를 `nil`에서 클로저로 바꾼다.)

```swift
.sheet(isPresented: $showBudget) {
    BudgetSheet(current: viewModel?.budget ?? 0) { amount in viewModel?.setBudget(amount) }
}
.sheet(isPresented: $showMonthStartDay) {
    MonthStartDaySheet(current: viewModel?.monthStartDay ?? 1) { day in viewModel?.setMonthStartDay(day) }
}
```
(기존 `.sheet(isPresented: $showBudget) { ... }` 바로 다음에 새 `.sheet` 추가.)

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodegen generate && xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`. "Test run with 96 tests ... passed"(95 + 신규 1개) 확인.

- [ ] **Step 5: 커밋**

```
git add WadeMoney/Screens/Settings/
git commit -m "fix(ui): wire up month-start-day setting row with a picker sheet"
```

---

### Task 3: 대시보드 카테고리 비중 카드 빈 상태 처리

**문제(조사 결과)**: `DonutRing.arcs`는 `legend`가 비어 있으면 빈 배열을 반환하고, `DonutRing.body`는 그 `arcs`만 그리므로 지출이 없는 기간엔 링 자체가 전혀 안 보이고 "총지출"+금액 텍스트만 허공에 떠 있다. `HeroBudgetCard`의 소진율 링은 `.background(Circle().stroke(WadeColors.track(scheme), lineWidth: 12))`로 빈 상태에도 회색 트랙 링을 그리는데, `DonutRing`엔 이 처리가 없다.

**Files:**
- Modify: `WadeMoney/Screens/Dashboard/DashboardComponents.swift`

**Interfaces:** 없음(순수 뷰 변경, `DonutCard`/`DonutRing`의 외부 시그니처는 그대로).

이 태스크는 뷰 전용이라 유닛 테스트가 없다(태스크 브리프가 아니라 이 문단이 근거: `legend`가 비는 조건 자체는 `DashboardViewModelTests`에서 이미 검증된 계산 로직이고, 여기서 고치는 건 그 결과를 렌더링하는 분기뿐이다). 빌드 성공 + 가능하면 스크린샷으로 검증한다.

- [ ] **Step 1: 구현**

`DashboardComponents.swift`의 `DonutCard`를 교체:

```swift
struct DonutCard: View {
    @Environment(\.colorScheme) private var scheme
    let total: String
    let legend: [DashboardViewModel.DonutLegendItem]
    var body: some View {
        card(scheme) {
            VStack(alignment: .leading, spacing: 16) {
                Text("카테고리 비중").font(WadeFont.pretendard(15, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                if legend.isEmpty {
                    emptyState
                } else {
                    HStack(spacing: 20) {
                        DonutRing(legend: legend, centerTotal: total)
                            .frame(width: 128, height: 128)
                        VStack(alignment: .leading, spacing: 9) {
                            ForEach(legend) { item in
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: item.colorHex)).frame(width: 10, height: 10)
                                    Text(item.name).font(WadeFont.pretendard(13, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(item.percentText).font(WadeFont.pretendard(13, weight: .heavy)).foregroundStyle(WadeColors.ink2(scheme))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle().stroke(WadeColors.track(scheme), lineWidth: 22).frame(width: 128, height: 128)
                VStack(spacing: 1) {
                    Text("총지출").font(WadeFont.pretendard(10.5, weight: .semibold)).foregroundStyle(WadeColors.ink3(scheme))
                    Text(total).font(WadeFont.pretendard(16, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                }
            }
            Text("아직 지출이 없어요").font(WadeFont.pretendard(13, weight: .semibold)).foregroundStyle(WadeColors.ink3(scheme))
            Spacer(minLength: 0)
        }
    }
}
```

(`item.name`에 `.lineLimit(1)`을 추가한 것은 이 계획의 태스크 5와 같은 종류의 좁은 화면 대응이지만, 어차피 이 파일을 같이 건드리므로 여기서 같이 처리한다 — 별도 태스크로 쪼개지 않는다.)

`DonutRing`은 수정하지 않는다(빈 상태는 `DonutCard`가 분기 처리하므로 `DonutRing`은 항상 `legend`가 비어있지 않을 때만 호출된다).

- [ ] **Step 2: 빌드 확인**

Run: `xcodegen generate && xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`. 기존 96개 테스트 그대로 통과 확인(이 태스크는 신규 테스트 없음).

- [ ] **Step 3: 화면 수동 검증(가능하면)**

시뮬레이터에서 카테고리 지출이 없는 기간(예: 미래 월로 이동)의 대시보드를 스크린샷으로 확인 — 회색 트랙 링 + "아직 지출이 없어요" 텍스트가 보여야 한다(빈 허공이 아니라).

- [ ] **Step 4: 커밋**

```
git add WadeMoney/Screens/Dashboard/DashboardComponents.swift
git commit -m "fix(ui): show a neutral track ring + empty-state text when the category donut has no data"
```

---

### Task 4: 바텀시트에 명시적 닫기 버튼 추가

**문제(조사 결과)**: `QuickAddSheet`/`BudgetSheet`/`CategoryEditSheet` 세 시트 모두 `.interactiveDismissDisabled`는 안 걸려 있어 스와이프 자체는 가능하지만, 명시적인 취소/닫기 버튼이 하나도 없다. `CategoryEditSheet`는 콘텐츠가 `ScrollView`라 스크롤이 맨 위가 아닐 때 아래로 스와이프하면 시트가 아니라 스크롤이 반응해서 "닫는 제스처가 안 먹는" 것처럼 느껴질 수 있고, `QuickAddSheet`는 메모 `TextField`에 포커스가 있으면 첫 스와이프가 키보드만 내리는 경우가 흔하다. 세 시트 모두에 명시적 X 버튼을 추가한다.

**Files:**
- Modify: `WadeMoney/Screens/QuickAdd/QuickAddSheet.swift`
- Modify: `WadeMoney/Screens/Settings/BudgetSheet.swift`
- Modify: `WadeMoney/Screens/Categories/CategoryEditSheet.swift`

**Interfaces:** 없음(순수 뷰 변경). 세 파일 모두 이미 `@Environment(\.dismiss) private var dismiss`를 갖고 있으므로 재사용한다.

이 태스크도 뷰 전용이라 유닛 테스트가 없다 — 빌드 성공으로 검증한다.

- [ ] **Step 1: 구현**

`QuickAddSheet.swift`의 헤더 `HStack`(현재 `Text(vm.isEditing ? ... )`로 시작)에 닫기 버튼을 맨 앞에 추가:

```swift
HStack {
    Button { dismiss() } label: {
        Icon("close", size: 20).foregroundStyle(WadeColors.ink2(scheme))
    }.buttonStyle(.plain)
    Text(vm.isEditing
         ? (vm.type == .income ? "수입 수정" : "지출 수정")
         : (vm.type == .income ? "새 수입" : "새 지출"))
        .font(WadeFont.pretendard(20, weight: .heavy))
    Spacer()
    if vm.isEditing {
        Button {
            try? vm.delete()
            onSaved()
            dismiss()
        } label: {
            Icon("delete", size: 20).foregroundStyle(WadeColors.bad(scheme))
        }.buttonStyle(.plain).padding(.trailing, 10)
    }
    typeToggle(vm)
}
.padding(.top, 16)
```

`BudgetSheet.swift`의 제목 줄(현재 `Text("이번 달 예산").font(...).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 16)`)을 헤더 `HStack`으로 교체:

```swift
HStack {
    Text("이번 달 예산").font(WadeFont.pretendard(20, weight: .heavy))
    Spacer()
    Button { dismiss() } label: {
        Icon("close", size: 20).foregroundStyle(WadeColors.ink2(scheme))
    }.buttonStyle(.plain)
}
.padding(.top, 16)
```

`CategoryEditSheet.swift`의 제목 줄(현재 `Text(isEditing ? "카테고리 수정" : "새 카테고리").font(...).padding(.top, 16)`)을 헤더 `HStack`으로 교체:

```swift
HStack {
    Text(isEditing ? "카테고리 수정" : "새 카테고리").font(WadeFont.pretendard(20, weight: .heavy))
    Spacer()
    Button { dismiss() } label: {
        Icon("close", size: 20).foregroundStyle(WadeColors.ink2(scheme))
    }.buttonStyle(.plain)
}
.padding(.top, 16)
```

- [ ] **Step 2: 빌드 확인**

Run: `xcodegen generate && xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`. 기존 96개 테스트 그대로 통과 확인.

- [ ] **Step 3: 화면 수동 검증(가능하면)**

빠른 입력 시트 / 예산 시트 / 카테고리 편집 시트 각각을 열어 우측 상단(또는 좌측)에 X 버튼이 보이고 탭하면 저장 없이 닫히는지 스크린샷으로 확인.

- [ ] **Step 4: 커밋**

```
git add WadeMoney/Screens/QuickAdd/QuickAddSheet.swift WadeMoney/Screens/Settings/BudgetSheet.swift WadeMoney/Screens/Categories/CategoryEditSheet.swift
git commit -m "fix(ui): add explicit close buttons to quick-add, budget, and category-edit sheets"
```

---

### Task 5: 좁은 화면 레이아웃 대응 (빠른입력 스크롤, 카테고리 그리드 반응형)

**문제(조사 결과)**: `QuickAddSheet`의 콘텐츠(`VStack`)는 스크롤 불가능한 상태로 제목+금액+카테고리 그리드+메모+키패드(고정 높이 ~260pt+)+저장 버튼을 전부 쌓는다 — iPhone SE 같은 작은 화면에서 콘텐츠가 화면을 넘으면 잘릴 수 있다. `CategoryEditSheet`의 아이콘/색상 그리드는 `count: 6` 고정 컬럼이라 매우 좁은 화면에서 46pt/42pt 타일 6개가 들어갈 공간이 부족하면 넘칠 수 있다.

**Files:**
- Modify: `WadeMoney/Screens/QuickAdd/QuickAddSheet.swift`
- Modify: `WadeMoney/Screens/Categories/CategoryEditSheet.swift`

**Interfaces:** 없음(순수 레이아웃 변경).

이 태스크도 뷰 전용이라 유닛 테스트가 없다 — 빌드 성공으로 검증한다.

- [ ] **Step 1: 구현**

`QuickAddSheet.swift`의 `content(_:)` 함수 본문을 `ScrollView`로 감싼다(태스크 4에서 추가한 헤더 닫기 버튼은 그대로 유지):

```swift
@ViewBuilder private func content(_ vm: QuickAddViewModel) -> some View {
    ScrollView {
        VStack(spacing: 14) {
            // ... 기존 내용(헤더 HStack부터 저장 버튼까지) 전부 그대로 ...
        }
        .padding(.horizontal, 20).padding(.bottom, 30)
    }
}
```
(기존에 `VStack` 바로 바깥에 있던 `.padding(.horizontal, 20).padding(.bottom, 30)`을 `VStack`에 그대로 두고, `ScrollView { }`로 한 겹 감싸기만 하면 된다 — 내부 내용은 손대지 않는다.)

`CategoryEditSheet.swift`의 아이콘 그리드와 색상 그리드, 두 곳의 `columns:` 파라미터를 고정 6컬럼에서 반응형으로 바꾼다:

```swift
LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
    ForEach(CategoryPalette.icons, id: \.self) { name in
        // ... 기존 그대로 ...
    }
}
```

```swift
LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 8)], spacing: 8) {
    ForEach(CategoryPalette.colors, id: \.self) { hex in
        // ... 기존 그대로 ...
    }
}
```
(아이콘 타일은 42pt 크기이므로 minimum 44, 색상 스와치는 36pt이므로 minimum 36 — 각 그리드 안의 실제 타일 크기에 맞춘 값이다.)

- [ ] **Step 2: 빌드 확인**

Run: `xcodegen generate && xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`. 기존 96개 테스트 그대로 통과 확인.

- [ ] **Step 3: 화면 수동 검증(가능하면)**

가능하면 iPhone SE(3rd generation) 시뮬레이터로 빠른 입력 시트와 카테고리 편집 시트를 스크린샷 — 빠른 입력 시트는 필요시 스크롤되고, 카테고리 그리드는 6열이 유지되거나 화면 폭에 맞게 자연스럽게 줄어드는지(넘치지 않는지) 확인. iPhone 17 Pro 시뮬레이터만 있다면 최소한 크래시 없이 정상 렌더링되는지만 확인.

- [ ] **Step 4: 커밋**

```
git add WadeMoney/Screens/QuickAdd/QuickAddSheet.swift WadeMoney/Screens/Categories/CategoryEditSheet.swift
git commit -m "fix(ui): make quick-add sheet scrollable and category grids adaptive on narrow screens"
```

---

## Final Review 가이드 (서브에이전트 주도 실행 시)

전체 브랜치 리뷰에서 특히 아래를 확인한다:
- 태스크 1의 `didSeedDefaultCategories` 플래그 로직이 기존 3개 시더 테스트(`seedsEightDefaultsOnEmptyStore`/`seedingIsIdempotent`/`firstCategoryMatchesDesignSpec`)를 깨지 않았는지.
- 카테고리 시드 수정이 기존 사용자 데이터를 삭제/병합하지 않는지(이 계획은 명시적으로 향후 방지만 다룬다 — Global Constraints 참고).
- 태스크 2의 새 시트가 `BudgetSheet`와 동일한 시각적 패턴(닫기 버튼 위치, 폰트, 색)을 따르는지.
- 태스크 3의 빈 상태 처리가 `HeroBudgetCard`의 기존 트랙 링 패턴과 톤이 일치하는지.
- 태스크 4·5가 같은 파일(`QuickAddSheet.swift`, `CategoryEditSheet.swift`)을 순차로 건드리므로, 태스크 5 구현 시 태스크 4에서 추가한 닫기 버튼이 실수로 지워지지 않았는지.
- 5개 태스크 누적 테스트 수가 실제로 96(93 + 2 + 1 + 0 + 0 + 0)과 일치하는지.
