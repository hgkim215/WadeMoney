# WadeMoney — 위젯 (WidgetKit) Implementation Plan (6/6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 홈 화면 위젯 3종(요약/빠른 기록/잠금화면)을 새 위젯 확장(Extension) 타깃으로 추가한다. 앱과 App Group으로 SwiftData 저장소를 공유해 읽고, 예산·거래 변경 시 자동 새로고침된다. Siri/단축어/App Intent는 이 계획의 범위에서 완전히 제외한다(사용자 결정).

**Architecture:** 신규 `WadeMoneyWidgets` 앱 확장 타깃을 만들고, 순수 데이터 로직(`WidgetDataBuilder`)은 앱 타깃과 위젯 타깃이 공유하는 `WadeMoney/Widgets/` 폴더에 둬서 기존 테스트 인프라(`WadeMoneyTests`, `@testable import WadeMoney`)로 TDD 검증한다. `Models`·`Mapping`·`Stores`·`Persistence`·`Formatting`·`DesignSystem` 소스는 두 타깃이 동일 파일을 공유(중복 없이 두 타깃의 `sources`에 나열)해 `LedgerRepository`/`SettingsStore` 등을 그대로 재사용한다. "홈 대화형 기록 위젯"은 WidgetKit interactive widget(App Intent 기반 위젯 내 자유 입력)이 기술적으로 불가능하므로, 카테고리 칩을 탭하면 앱의 빠른 입력 시트로 딥링크(`wademoney://quickadd?category=…`)하는 방식으로 구현한다(사용자 결정).

**Tech Stack:** WidgetKit, SwiftUI, SwiftData, `WadeMoneyCore`, Swift Testing, XcodeGen, iOS 26 시뮬레이터.

## WidgetKit API 확인 (근거)

계획 작성 전 Xcode 26.6 SDK의 실제 선언을 `WidgetKit.framework`/`SwiftUI.framework`의 `.swiftinterface`에서 직접 확인했다:
- `protocol TimelineProvider { associatedtype Entry: TimelineEntry; func placeholder(in:) -> Entry; func getSnapshot(in:completion:); func getTimeline(in:completion:) }` — 전부 콜백 기반(비-async), `@preconcurrency`로 표시돼 있어 임의 격리 컨텍스트에서 호출 가능.
- `StaticConfiguration<Content>(kind: String, provider: Provider, content: @escaping (Provider.Entry) -> Content)` (`Provider: TimelineProvider`).
- `WidgetCenter.shared.reloadTimelines(ofKind:)` / (관례상) `reloadAllTimelines()`.
- `WidgetFamily`에 `.accessoryCircular`, `.accessoryInline` 포함(잠금화면 액세서리).
- SwiftUI: `AccessoryCircularCapacityGaugeStyle`(`Gauge(...).gaugeStyle(.accessoryCircularCapacity)`), `containerBackground(_:for:)` — 두 API 모두 존재 확인.
- 최소 iOS 버전 14.0(대부분)/일부 accessory 관련은 iOS 16+ — 프로젝트 배포 타깃(iOS 26.0)이 전부 충족.

## 사전 확정된 설계 결정 (사용자 승인)

1. **인터랙티브 위젯 대체**: 디자인 스펙 §7의 "홈 대화형 기록 위젯"(칩 탭 → 위젯 안에서 금액 입력해 기록)은 WidgetKit 기술적 제약(위젯 내부에 자유 숫자 입력 불가)으로 구현 불가. **칩 탭 → 앱의 빠른 입력 시트로 딥링크**(카테고리 사전 선택)하는 방식으로 대체한다.
2. **범위**: 홈 요약 위젯 + 홈 빠른 기록(딥링크) 위젯 + 잠금화면 위젯. **Siri/단축어/액션버튼/App Intent는 이 프로젝트에서 완전히 제외**(추후 계획에도 없음).

## Global Constraints

- **범위**: 위 3종 위젯 + 이를 지원하는 확장 타깃/공유 소스/딥링크. App Intents·Siri·Shortcuts 관련 코드는 일절 작성하지 않는다.
- **디자인 정본**: `docs/design/app-design-specification-analysis/project/WadeMoney 가계부.dc.html` §7(위젯), 디자인 시스템 문서 §7. 다만 위젯은 시스템이 다크모드/잠금화면 틴트를 강제 적용하는 영역(특히 액세서리 계열)이 있어, 앱 화면만큼의 픽셀 일치는 요구하지 않는다 — 톤(WadeColors/WadeFont/Icon)을 최대한 재사용하되 WidgetKit 렌더링 제약을 우선한다.
- **읽기 전용**: 위젯 확장은 SwiftData 저장소를 **읽기만** 한다. 쓰기(거래 기록)는 항상 앱으로 딥링크해서 처리한다 — 위젯 프로세스에서 `context.save()`를 호출하는 코드를 작성하지 않는다.
- **App Group 전용, CloudKit 직접 접근 금지**: 위젯의 `ModelConfiguration`은 `groupContainer: .identifier(AppIDs.appGroup)`만 사용하고 `cloudKitDatabase`를 지정하지 않는다(동기화는 앱이 전담). App Group이 프로비저닝되지 않은 환경(미서명 시뮬레이터)에서는 크래시 대신 빈 인메모리 컨테이너로 폴백한다(`PersistenceController`의 기존 크래시 방지 패턴과 동일 원칙).
- **엔진 순수성 유지**: `Date()`/`Calendar.current` 직접 호출 금지 — `now`/`calendar`는 TimelineProvider 진입점에서만 만들고 그 아래로는 주입.
- **테스트 가능한 계층 분리**: 위젯이 표시할 데이터를 계산하는 로직(`WidgetDataBuilder`)은 WidgetKit을 import하지 않는 순수 함수로 작성해 `WadeMoneyTests`에서 `@testable import WadeMoney`로 TDD 검증한다. `TimelineProvider`/`Widget`/SwiftUI 뷰 자체(WidgetKit 의존)는 위젯 확장 타깃에서만 컴파일되며 단위 테스트 대상이 아니다 — 빌드 성공(+확장 임베드 확인)으로 검증한다.
- **위젯 시각 검증의 한계**: 위젯은 시뮬레이터 홈 화면에 수동으로 추가해야 미리보기가 가능하고, 이 세션에서는 안전한 시뮬레이터 탭 자동화 도구가 없다(계획 5에서 이미 확인된 한계 — 우발적으로 다른 창을 클릭한 사례 있음). 이 계획에서는 위젯 UI의 스크린샷 검증을 **강제하지 않는다** — 빌드 성공 + `WidgetDataBuilder` 단위 테스트 + 코드 리뷰가 1차 품질 게이트다. Xcode의 `#Preview(as:)` 매크로로 각 위젯 파일에 미리보기를 추가해 향후 사람이 Xcode에서 직접 확인할 수 있게 한다.
- **빌드/테스트**(서명 없이): `xcodegen generate` → `xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`. 스킴이 `WadeMoneyWidgets` 타깃도 빌드하도록 구성되므로, 위젯 코드의 컴파일 오류도 이 커맨드로 잡힌다. Swift Testing 결과는 "Test run with N tests ... passed" 라인으로 확인. SourceKit IDE의 "No such module" 류는 오류 아님.
- SwiftData 테스트 헬퍼는 반드시 `ModelContainer`를 보유(미보유 시 dealloc 크래시).
- `.build/`·`*.xcodeproj`·`DerivedData/` 추적 금지. 커밋은 자주.
- 시작 테스트 수: 82 (계획 5 종료 시점). 각 태스크가 누적 증가.

---

### Task 1: 위젯 확장 타깃 스캐폴딩

새 앱 확장(Extension) 타깃을 만들고, 최소한의 플레이스홀더 위젯으로 빌드+임베드가 성공하는지 확인한다. 이후 태스크가 이 타깃 위에 실제 위젯을 얹는다.

**Files:**
- Modify: `project.yml`
- Create: `WadeMoney/DeepLink.swift` (앱·위젯 공유)
- Create: `WadeMoneyWidgetsExtension/WadeMoneyWidgets.entitlements`
- Create: `WadeMoneyWidgetsExtension/Info.plist`
- Create: `WadeMoneyWidgetsExtension/WadeMoneyWidgetsBundle.swift`
- Create: `WadeMoneyWidgetsExtension/PlaceholderWidget.swift`

**Interfaces:**
- `enum DeepLink { static let scheme = "wademoney"; static func quickAdd(categoryID: UUID?) -> URL; static func categoryID(from url: URL) -> UUID?; static func isQuickAdd(_ url: URL) -> Bool }`

- [ ] **Step 1: project.yml에 신규 타깃 추가**

`project.yml`의 `targets:` 아래에 `WadeMoney` 타깃 바로 다음에 `WadeMoneyWidgets` 타깃을 추가하고, `WadeMoney` 타깃의 `dependencies`에 임베드 의존성을 추가한다:

```yaml
targets:
  WadeMoney:
    type: application
    platform: iOS
    sources:
      - WadeMoney
    dependencies:
      - package: WadeMoneyCore
      - target: WadeMoneyWidgets
        embed: true
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.kimhyeongi.WadeMoney
        CODE_SIGN_ENTITLEMENTS: WadeMoney/WadeMoney.entitlements
        GENERATE_INFOPLIST_FILE: "NO"
        INFOPLIST_FILE: WadeMoney/Info.plist
        TARGETED_DEVICE_FAMILY: "1"
  WadeMoneyWidgets:
    type: app-extension
    platform: iOS
    sources:
      - path: WadeMoney/Models
      - path: WadeMoney/Mapping
      - path: WadeMoney/Stores
      - path: WadeMoney/Persistence
      - path: WadeMoney/Formatting
      - path: WadeMoney/DesignSystem
      - path: WadeMoney/Widgets
      - path: WadeMoney/Constants.swift
      - path: WadeMoney/DeepLink.swift
      - path: WadeMoney/Resources/Fonts
      - path: WadeMoneyWidgetsExtension
    dependencies:
      - package: WadeMoneyCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.kimhyeongi.WadeMoney.Widgets
        CODE_SIGN_ENTITLEMENTS: WadeMoneyWidgetsExtension/WadeMoneyWidgets.entitlements
        GENERATE_INFOPLIST_FILE: "NO"
        INFOPLIST_FILE: WadeMoneyWidgetsExtension/Info.plist
        TARGETED_DEVICE_FAMILY: "1"
  WadeMoneyTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - WadeMoneyTests
    dependencies:
      - target: WadeMoney
      - package: WadeMoneyCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.kimhyeongi.WadeMoneyTests
        GENERATE_INFOPLIST_FILE: "YES"
schemes:
  WadeMoney:
    build:
      targets:
        WadeMoney: all
        WadeMoneyWidgets: all
        WadeMoneyTests: [test]
    test:
      targets:
        - WadeMoneyTests
```

주의: `WadeMoney/Widgets/`는 이 태스크에서 아직 파일이 없는 빈 폴더가 된다(태스크 2에서 `WidgetDataBuilder.swift`가 생김) — XcodeGen은 빈 폴더를 소스 경로로 지정해도 오류를 내지 않지만, 안전하게 하려면 `.gitkeep` 등을 두거나 태스크 2와 순서를 바꾸지 말 것(태스크 2가 바로 다음이라 실질적으로 빈 채로 남는 시간이 짧다). `WadeMoney` 타깃은 기존처럼 `sources: [WadeMoney]`(전체 폴더 재귀 포함)이므로 `WadeMoney/DeepLink.swift`·`WadeMoney/Widgets/*`가 이미 자동으로 포함된다 — `WadeMoney` 타깃의 sources를 따로 손댈 필요 없다.

- [ ] **Step 2: 딥링크 헬퍼 작성**

`WadeMoney/DeepLink.swift`:

```swift
import Foundation

enum DeepLink {
    static let scheme = "wademoney"

    /// category가 nil이면 카테고리 미선택 상태로 빠른 입력 시트를 연다("직접" 칩).
    static func quickAdd(categoryID: UUID?) -> URL {
        var comps = URLComponents()
        comps.scheme = scheme
        comps.host = "quickadd"
        if let categoryID {
            comps.queryItems = [URLQueryItem(name: "category", value: categoryID.uuidString)]
        }
        return comps.url!
    }

    static func isQuickAdd(_ url: URL) -> Bool {
        url.scheme == scheme && url.host == "quickadd"
    }

    static func categoryID(from url: URL) -> UUID? {
        guard isQuickAdd(url) else { return nil }
        guard let item = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "category" }) else { return nil }
        return item.value.flatMap { UUID(uuidString: $0) }
    }
}
```

- [ ] **Step 3: 위젯 확장 타깃 파일 작성**

`WadeMoneyWidgetsExtension/WadeMoneyWidgets.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.kimhyeongi.WadeMoney</string>
    </array>
</dict>
</plist>
```

`WadeMoneyWidgetsExtension/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleDisplayName</key>
    <string>WadeMoney Widgets</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>$(MARKETING_VERSION)</string>
    <key>CFBundleVersion</key>
    <string>$(CURRENT_PROJECT_VERSION)</string>
    <key>UIAppFonts</key>
    <array>
        <string>PretendardVariable.ttf</string>
        <string>MaterialSymbolsRounded.ttf</string>
    </array>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
```

`WadeMoneyWidgetsExtension/PlaceholderWidget.swift`:

```swift
import WidgetKit
import SwiftUI

struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: Date())
    }
    func getSnapshot(in context: Context, completion: @escaping @Sendable (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [PlaceholderEntry(date: Date())], policy: .never))
    }
}

struct PlaceholderWidgetView: View {
    var body: some View {
        Text("WadeMoney").containerBackground(.fill.tertiary, for: .widget)
    }
}

struct PlaceholderWidget: Widget {
    let kind = "WadeMoneyPlaceholderWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { _ in
            PlaceholderWidgetView()
        }
        .configurationDisplayName("WadeMoney")
        .description("준비 중입니다.")
    }
}
```

`WadeMoneyWidgetsExtension/WadeMoneyWidgetsBundle.swift`:

```swift
import WidgetKit
import SwiftUI

@main
struct WadeMoneyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PlaceholderWidget()
    }
}
```

- [ ] **Step 4: 빌드 + 임베드 확인**

```
xcodegen generate
xcodebuild build -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
find /Users/mac/Library/Developer/Xcode/DerivedData -iname "WadeMoneyWidgets.appex" -path "*Debug-iphonesimulator*"
```

`** BUILD SUCCEEDED **`와 함께 `WadeMoneyWidgets.appex` 경로가 최소 1개 출력되면(앱 번들의 `PlugIns/` 아래) 임베드 성공. 이어서 `xcodebuild test ...`(전체 커맨드)로 기존 82개 테스트가 그대로 통과하는지 확인(이 태스크는 신규 테스트 없음).

- [ ] **Step 5: 커밋**

```
git add project.yml WadeMoney/DeepLink.swift WadeMoneyWidgetsExtension/
git commit -m "feat(widgets): scaffold WadeMoneyWidgets extension target"
```

---

### Task 2: 홈 요약 위젯 (오늘 지출 + 이달 예산 잔액)

**Files:**
- Create: `WadeMoney/Widgets/WidgetDataBuilder.swift` (공유, WidgetKit import 없음)
- Create: `WadeMoneyWidgetsExtension/SummaryWidget.swift`
- Modify: `WadeMoneyWidgetsExtension/WadeMoneyWidgetsBundle.swift` (플레이스홀더 → 실 위젯으로 교체)
- Delete: `WadeMoneyWidgetsExtension/PlaceholderWidget.swift`
- Test: `WadeMoneyTests/WidgetDataBuilderTests.swift`

**Interfaces:**
- `enum WidgetDataBuilder { struct SummaryData { let todayExpenseText: String; let monthRemainingText: String?; let consumedFraction: Double? }; static func summary(repository: LedgerRepository, now: Date, calendar: Calendar) -> SummaryData }`

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/WidgetDataBuilderTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct WidgetDataBuilderTests {
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

    @Test func summaryReflectsTodayExpenseAndMonthRemaining() throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(300_000, for: YearMonth(year: 2026, month: 7))
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 12_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 15))
        try repo.addTransaction(amount: 50_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 3))

        let data = WidgetDataBuilder.summary(repository: repo, now: date(2026, 7, 15), calendar: utc)
        #expect(data.todayExpenseText == "12,000")
        #expect(data.monthRemainingText == "238,000원 남음")
        #expect(data.consumedFraction != nil)
        _ = container
    }

    @Test func summaryHandlesNoBudgetGracefully() throws {
        let (repo, _, container) = try makeRepo()
        let data = WidgetDataBuilder.summary(repository: repo, now: date(2026, 7, 15), calendar: utc)
        #expect(data.todayExpenseText == "0")
        #expect(data.monthRemainingText == nil)
        _ = container
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ...`. `WidgetDataBuilder` 미정의로 컴파일 실패해야 한다.

- [ ] **Step 3: 구현**

`WadeMoney/Widgets/WidgetDataBuilder.swift`:

```swift
import Foundation
import WadeMoneyCore

/// 위젯이 표시할 데이터를 계산하는 순수 로직. WidgetKit을 import하지 않아
/// 앱 타깃(WadeMoneyTests)에서 TDD로 검증할 수 있고, 위젯 확장 타깃에서도
/// 동일 파일을 공유해 TimelineProvider가 그대로 사용한다.
enum WidgetDataBuilder {
    struct SummaryData {
        let todayExpenseText: String
        let monthRemainingText: String?
        let consumedFraction: Double?
    }

    static func summary(repository: LedgerRepository, now: Date, calendar: Calendar) -> SummaryData {
        guard
            let day = try? repository.dashboardSummary(kind: .day, offset: 0, now: now, calendar: calendar),
            let month = try? repository.dashboardSummary(kind: .month, offset: 0, now: now, calendar: calendar)
        else {
            return SummaryData(todayExpenseText: "0", monthRemainingText: nil, consumedFraction: nil)
        }
        return SummaryData(
            todayExpenseText: Won.string(day.totalExpense),
            monthRemainingText: month.remaining.map { "\(Won.string($0))원 남음" },
            consumedFraction: month.consumedFraction
        )
    }
}
```

`WadeMoneyWidgetsExtension/SummaryWidget.swift`:

```swift
import WidgetKit
import SwiftUI
import SwiftData

struct SummaryEntry: TimelineEntry {
    let date: Date
    let data: WidgetDataBuilder.SummaryData
}

struct SummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> SummaryEntry {
        SummaryEntry(date: Date(), data: .init(todayExpenseText: "12,000", monthRemainingText: "840,000원 남음", consumedFraction: 0.42))
    }
    func getSnapshot(in context: Context, completion: @escaping @Sendable (SummaryEntry) -> Void) {
        completion(placeholder(in: context))
    }
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<SummaryEntry>) -> Void) {
        Task { @MainActor in
            let container = WidgetPersistence.makeContainer()
            let repo = LedgerRepository(context: container.mainContext)
            let now = Date()
            let data = WidgetDataBuilder.summary(repository: repo, now: now, calendar: .current)
            let next = Calendar.current.date(byAdding: .hour, value: 4, to: now) ?? now.addingTimeInterval(4 * 3600)
            completion(Timeline(entries: [SummaryEntry(date: now, data: data)], policy: .after(next)))
        }
    }
}

struct SummaryWidgetView: View {
    @Environment(\.colorScheme) private var scheme
    let entry: SummaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("오늘 지출").font(WadeFont.pretendard(11, weight: .semibold)).foregroundStyle(WadeColors.ink3(scheme))
            Text("₩\(entry.data.todayExpenseText)").font(WadeFont.pretendard(22, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
            if let frac = entry.data.consumedFraction {
                ProgressView(value: min(1, frac)).tint(WadeColors.primary(scheme))
            }
            if let remain = entry.data.monthRemainingText {
                Text("이달 예산 \(remain)").font(WadeFont.pretendard(10.5)).foregroundStyle(WadeColors.ink3(scheme))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(WadeColors.card(scheme), for: .widget)
    }
}

struct SummaryWidget: Widget {
    let kind = "WadeMoneySummaryWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SummaryProvider()) { entry in
            SummaryWidgetView(entry: entry)
        }
        .configurationDisplayName("오늘 지출 요약")
        .description("오늘 지출과 이달 예산 잔액을 한눈에 봐요.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    SummaryWidget()
} timeline: {
    SummaryEntry(date: .now, data: .init(todayExpenseText: "12,000", monthRemainingText: "840,000원 남음", consumedFraction: 0.42))
}
```

`WadeMoneyWidgetsExtension/PlaceholderWidget.swift`를 삭제하고, `WadeMoneyWidgetsExtension/WadeMoneyWidgetsBundle.swift`를 수정:

```swift
import WidgetKit
import SwiftUI

@main
struct WadeMoneyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SummaryWidget()
    }
}
```

`WadeMoney/Persistence/WidgetPersistence.swift`(신규, 공유):

```swift
import Foundation
import SwiftData

/// 위젯은 앱이 쓴 App Group 공유 저장소를 읽기만 한다(CloudKit 동기화는 앱이 전담).
/// App Group이 프로비저닝되지 않은 환경(미서명 시뮬레이터 등)에서는 크래시 대신
/// 빈 인메모리 컨테이너로 폴백한다 — PersistenceController의 크래시 방지 패턴과 동일 원칙.
enum WidgetPersistence {
    private static var isAppGroupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppIDs.appGroup) != nil
    }

    static func makeContainer() -> ModelContainer {
        guard isAppGroupAvailable else { return emptyFallback() }
        do {
            let config = ModelConfiguration(schema: PersistenceController.sharedSchema, groupContainer: .identifier(AppIDs.appGroup))
            return try ModelContainer(for: PersistenceController.sharedSchema, configurations: [config])
        } catch {
            return emptyFallback()
        }
    }

    private static func emptyFallback() -> ModelContainer {
        let config = ModelConfiguration(schema: PersistenceController.sharedSchema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: PersistenceController.sharedSchema, configurations: [config])
    }
}
```

(이 파일은 `WadeMoney/Persistence/`에 두므로 두 타깃 모두의 `sources`에 이미 포함된 `WadeMoney/Persistence` 경로로 자동으로 같이 딸려온다 — project.yml을 추가로 손댈 필요 없다.)

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodegen generate && xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`. "Test run with 84 tests ... passed"(82 + 신규 2개) 확인.

- [ ] **Step 5: 커밋**

```
git add WadeMoney/Widgets/ WadeMoney/Persistence/WidgetPersistence.swift WadeMoneyWidgetsExtension/ WadeMoneyTests/WidgetDataBuilderTests.swift
git commit -m "feat(widgets): add home summary widget (today expense + month budget remaining)"
```

---

### Task 3: 빠른 기록 위젯 (카테고리 칩 → 앱 딥링크) + 앱 쪽 딥링크 처리

**Files:**
- Modify: `WadeMoney/Widgets/WidgetDataBuilder.swift`
- Create: `WadeMoneyWidgetsExtension/QuickRecordWidget.swift`
- Modify: `WadeMoneyWidgetsExtension/WadeMoneyWidgetsBundle.swift`
- Modify: `WadeMoney/Info.plist` (URL scheme 등록)
- Modify: `WadeMoney/Screens/RootTabView.swift` (딥링크 수신 → 빠른 입력 시트 오픈)
- Modify: `WadeMoney/Screens/QuickAdd/QuickAddViewModel.swift` (`preselectedCategoryID` 지원)
- Modify: `WadeMoney/Screens/QuickAdd/QuickAddSheet.swift`
- Test: `WadeMoneyTests/WidgetDataBuilderTests.swift`(확장), `WadeMoneyTests/DeepLinkTests.swift`(신규), `WadeMoneyTests/QuickAddEditTests.swift` 또는 신규 파일(프리셀렉트 테스트)

**Interfaces:**
- `WidgetDataBuilder`에 추가: `struct ChipData: Identifiable { let id: UUID; let name: String; let iconName: String; let colorHex: String }; static func quickRecordChips(repository: LedgerRepository) -> [ChipData]` — `sortOrder` 오름차순 활성 카테고리 상위 3개.
- `QuickAddViewModel.init(repository:editing:preselectedCategoryID: UUID? = nil, aiAvailability:memoPolisher:)` — `editing`이 nil이고 `preselectedCategoryID`가 있으면 `selectedCategoryID`를 그 값으로 초기화.
- `QuickAddSheet`에 `var preselectedCategoryID: UUID? = nil` 추가.

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/WidgetDataBuilderTests.swift`에 추가:

```swift
extension WidgetDataBuilderTests {
    @Test func quickRecordChipsReturnsTopThreeActiveCategoriesBySortOrder() throws {
        let (repo, _, container) = try makeRepo()
        let chips = WidgetDataBuilder.quickRecordChips(repository: repo)
        #expect(chips.count == 3)
        #expect(chips.map(\.name) == ["식비", "카페", "교통"])   // 시드 순서(§6) 첫 3개
        _ = container
    }

    @Test func quickRecordChipsExcludesArchivedCategories() throws {
        let (repo, _, container) = try makeRepo()
        let food = try catID(repo, "식비")
        try CategoryStore(context: container.mainContext).archive(id: food)
        let chips = WidgetDataBuilder.quickRecordChips(repository: repo)
        #expect(!chips.contains { $0.name == "식비" })
        _ = container
    }
}
```

`WadeMoneyTests/DeepLinkTests.swift`(신규):

```swift
import Foundation
import Testing
@testable import WadeMoney

struct DeepLinkTests {
    @Test func buildsAndParsesCategoryDeepLink() {
        let id = UUID()
        let url = DeepLink.quickAdd(categoryID: id)
        #expect(DeepLink.isQuickAdd(url))
        #expect(DeepLink.categoryID(from: url) == id)
    }

    @Test func buildsDeepLinkWithoutCategoryForManualEntry() {
        let url = DeepLink.quickAdd(categoryID: nil)
        #expect(DeepLink.isQuickAdd(url))
        #expect(DeepLink.categoryID(from: url) == nil)
    }

    @Test func rejectsUnrelatedURL() {
        let url = URL(string: "https://example.com")!
        #expect(!DeepLink.isQuickAdd(url))
        #expect(DeepLink.categoryID(from: url) == nil)
    }
}
```

`WadeMoneyTests/QuickAddPreselectTests.swift`(신규):

```swift
import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct QuickAddPreselectTests {
    func repo() throws -> (LedgerRepository, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        return (LedgerRepository(context: container.mainContext), container)
    }
    func catID(_ r: LedgerRepository, _ n: String) throws -> UUID {
        try r.allCategories(includeArchived: false).first { $0.name == n }!.id
    }

    @Test func preselectsCategoryWhenAddingNew() throws {
        let (r, c) = try repo()
        let cafe = try catID(r, "카페")
        let vm = QuickAddViewModel(repository: r, preselectedCategoryID: cafe)
        #expect(vm.selectedCategoryID == cafe)
        #expect(!vm.isEditing)
        _ = c
    }

    @Test func noPreselectionMeansNoCategorySelected() throws {
        let (r, c) = try repo()
        let vm = QuickAddViewModel(repository: r)
        #expect(vm.selectedCategoryID == nil)
        _ = c
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ...`. `quickRecordChips`/`DeepLink`/`preselectedCategoryID` 미정의로 컴파일 실패해야 한다.

- [ ] **Step 3: 구현**

`WidgetDataBuilder.swift`에 추가:

```swift
extension WidgetDataBuilder {
    struct ChipData: Identifiable {
        let id: UUID
        let name: String
        let iconName: String
        let colorHex: String
    }

    /// sortOrder 오름차순 활성 카테고리 상위 3개("직접" 칩은 위젯 뷰에서 별도 추가).
    static func quickRecordChips(repository: LedgerRepository) -> [ChipData] {
        let categories = (try? repository.allCategories(includeArchived: false)) ?? []
        return categories.prefix(3).map {
            ChipData(id: $0.id, name: $0.name, iconName: $0.iconName, colorHex: $0.colorHex)
        }
    }
}
```

`WadeMoneyWidgetsExtension/QuickRecordWidget.swift`:

```swift
import WidgetKit
import SwiftUI
import SwiftData

struct QuickRecordEntry: TimelineEntry {
    let date: Date
    let chips: [WidgetDataBuilder.ChipData]
}

struct QuickRecordProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickRecordEntry {
        QuickRecordEntry(date: Date(), chips: [])
    }
    func getSnapshot(in context: Context, completion: @escaping @Sendable (QuickRecordEntry) -> Void) {
        completion(placeholder(in: context))
    }
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<QuickRecordEntry>) -> Void) {
        Task { @MainActor in
            let container = WidgetPersistence.makeContainer()
            let repo = LedgerRepository(context: container.mainContext)
            let chips = WidgetDataBuilder.quickRecordChips(repository: repo)
            let now = Date()
            let next = Calendar.current.date(byAdding: .hour, value: 12, to: now) ?? now.addingTimeInterval(12 * 3600)
            completion(Timeline(entries: [QuickRecordEntry(date: now, chips: chips)], policy: .after(next)))
        }
    }
}

struct QuickRecordWidgetView: View {
    @Environment(\.colorScheme) private var scheme
    let entry: QuickRecordEntry

    var body: some View {
        HStack(spacing: 8) {
            ForEach(entry.chips) { chip in
                Link(destination: DeepLink.quickAdd(categoryID: chip.id)) {
                    chipLabel(icon: chip.iconName, name: chip.name, tint: Color(hex: chip.colorHex))
                }
            }
            Link(destination: DeepLink.quickAdd(categoryID: nil)) {
                chipLabel(icon: "add", name: "직접", tint: WadeColors.ink2(scheme))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(WadeColors.card(scheme), for: .widget)
    }

    private func chipLabel(icon: String, name: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Icon(icon, size: 18).foregroundStyle(tint)
            Text(name).font(WadeFont.pretendard(10, weight: .bold)).foregroundStyle(WadeColors.ink(scheme))
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickRecordWidget: Widget {
    let kind = "WadeMoneyQuickRecordWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickRecordProvider()) { entry in
            QuickRecordWidgetView(entry: entry)
        }
        .configurationDisplayName("빠른 기록")
        .description("카테고리를 탭해 바로 지출 입력 화면으로 이동해요.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    QuickRecordWidget()
} timeline: {
    QuickRecordEntry(date: .now, chips: [
        .init(id: UUID(), name: "식비", iconName: "restaurant", colorHex: "#E28A4E"),
        .init(id: UUID(), name: "카페", iconName: "local_cafe", colorHex: "#C4924E"),
        .init(id: UUID(), name: "교통", iconName: "directions_bus", colorHex: "#6F9FD8"),
    ])
}
```

`WadeMoneyWidgetsExtension/WadeMoneyWidgetsBundle.swift` 수정:

```swift
import WidgetKit
import SwiftUI

@main
struct WadeMoneyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SummaryWidget()
        QuickRecordWidget()
    }
}
```

`WadeMoney/Info.plist`에 URL scheme 추가(`UIBackgroundModes` 항목 근처에):

```xml
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>wademoney</string>
            </array>
            <key>CFBundleURLName</key>
            <string>com.kimhyeongi.WadeMoney</string>
        </dict>
    </array>
```

`QuickAddViewModel.swift` — `init`에 파라미터 추가(기존 `editing`/`aiAvailability`/`memoPolisher`는 그대로):

```swift
init(
    repository: LedgerRepository, editing: TransactionRecord? = nil,
    preselectedCategoryID: UUID? = nil,
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
        self.selectedCategoryID = preselectedCategoryID
    }
}
```

`QuickAddSheet.swift` — `preselectedCategoryID` 프로퍼티 추가 및 `onAppear`에서 전달:

```swift
var editing: TransactionRecord? = nil
var preselectedCategoryID: UUID? = nil
...
.onAppear {
    if vm == nil {
        vm = QuickAddViewModel(repository: LedgerRepository(context: modelContext), editing: editing, preselectedCategoryID: preselectedCategoryID)
    }
}
```

`RootTabView.swift` — 딥링크 수신 상태 및 처리 추가:

```swift
struct RootTabView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var selection = 0
    @State private var showAdd = false
    @State private var quickAddCategoryID: UUID?
    @State private var dashboardRefreshToken = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selection {
                case 0: DashboardScreen(refreshToken: dashboardRefreshToken)
                case 1: HistoryScreen(refreshToken: dashboardRefreshToken)
                case 4: SettingsScreen()
                default: DashboardScreen(refreshToken: dashboardRefreshToken)
                }
            }
            tabBar
        }
        .ignoresSafeArea(.keyboard)
        .onOpenURL { url in
            guard DeepLink.isQuickAdd(url) else { return }
            quickAddCategoryID = DeepLink.categoryID(from: url)
            showAdd = true
        }
        .sheet(isPresented: $showAdd, onDismiss: { quickAddCategoryID = nil }) {
            QuickAddSheet(onSaved: { dashboardRefreshToken += 1 }, preselectedCategoryID: quickAddCategoryID)
        }
    }
    // ... 나머지(tabBar/tabButton/statsTab/fab)는 변경 없음
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodegen generate && xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`. "Test run with 91 tests ... passed"(84 + 신규 7개: quickRecordChips 2 + DeepLink 3 + QuickAddPreselect 2) 확인.

- [ ] **Step 5: 화면 수동 검증(가능한 범위)**

시뮬레이터에서 앱을 빌드+설치한 뒤, 터미널에서 딥링크를 직접 열어본다(시뮬레이터 탭 자동화 없이도 가능):

```
xcrun simctl openurl booted "wademoney://quickadd?category=<임의-uuid>"
```

앱이 이미 실행 중이면 빠른 입력 시트가 뜨는지(카테고리가 실제 존재하는 UUID가 아니면 카테고리 미선택 상태로 열리는 것도 정상 — 프리셀렉트 실패를 조용히 무시하는지) 확인하고 스크린샷을 개인적으로 확인한다. 위젯 자체(칩 탭)는 이 태스크에서 시각 검증하지 않는다(Global Constraints 참고).

- [ ] **Step 6: 커밋**

```
git add WadeMoney/Widgets/ WadeMoneyWidgetsExtension/ WadeMoney/Info.plist WadeMoney/Screens/RootTabView.swift WadeMoney/Screens/QuickAdd/ WadeMoneyTests/
git commit -m "feat(widgets): add quick-record widget with deep link to quick-add sheet"
```

---

### Task 4: 잠금화면 위젯 (원형 + 인라인 액세서리)

**Files:**
- Modify: `WadeMoney/Widgets/WidgetDataBuilder.swift`
- Create: `WadeMoneyWidgetsExtension/LockScreenBudgetWidget.swift`
- Modify: `WadeMoneyWidgetsExtension/WadeMoneyWidgetsBundle.swift`
- Test: `WadeMoneyTests/WidgetDataBuilderTests.swift`(확장)

**Interfaces:**
- `WidgetDataBuilder`에 추가: `struct LockScreenData { let consumedFraction: Double?; let remainingText: String? }; static func lockScreenBudget(repository: LedgerRepository, now: Date, calendar: Calendar) -> LockScreenData`

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/WidgetDataBuilderTests.swift`에 추가:

```swift
extension WidgetDataBuilderTests {
    @Test func lockScreenBudgetReflectsMonthRemaining() throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(100_000, for: YearMonth(year: 2026, month: 7))
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 40_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))

        let data = WidgetDataBuilder.lockScreenBudget(repository: repo, now: date(2026, 7, 15), calendar: utc)
        #expect(data.remainingText == "60,000원")
        #expect(data.consumedFraction != nil)
        _ = container
    }

    @Test func lockScreenBudgetNilWhenNoBudgetSet() throws {
        let (repo, _, container) = try makeRepo()
        let data = WidgetDataBuilder.lockScreenBudget(repository: repo, now: date(2026, 7, 15), calendar: utc)
        #expect(data.remainingText == nil)
        #expect(data.consumedFraction == nil)
        _ = container
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ...`.

- [ ] **Step 3: 구현**

`WidgetDataBuilder.swift`에 추가:

```swift
extension WidgetDataBuilder {
    struct LockScreenData {
        let consumedFraction: Double?
        let remainingText: String?
    }

    static func lockScreenBudget(repository: LedgerRepository, now: Date, calendar: Calendar) -> LockScreenData {
        guard let month = try? repository.dashboardSummary(kind: .month, offset: 0, now: now, calendar: calendar) else {
            return LockScreenData(consumedFraction: nil, remainingText: nil)
        }
        return LockScreenData(
            consumedFraction: month.consumedFraction,
            remainingText: month.remaining.map { "\(Won.string($0))원" }
        )
    }
}
```

`WadeMoneyWidgetsExtension/LockScreenBudgetWidget.swift`:

```swift
import WidgetKit
import SwiftUI
import SwiftData

struct LockScreenEntry: TimelineEntry {
    let date: Date
    let data: WidgetDataBuilder.LockScreenData
}

struct LockScreenProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScreenEntry {
        LockScreenEntry(date: Date(), data: .init(consumedFraction: 0.42, remainingText: "840,000원"))
    }
    func getSnapshot(in context: Context, completion: @escaping @Sendable (LockScreenEntry) -> Void) {
        completion(placeholder(in: context))
    }
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<LockScreenEntry>) -> Void) {
        Task { @MainActor in
            let container = WidgetPersistence.makeContainer()
            let repo = LedgerRepository(context: container.mainContext)
            let now = Date()
            let data = WidgetDataBuilder.lockScreenBudget(repository: repo, now: now, calendar: .current)
            let next = Calendar.current.date(byAdding: .hour, value: 4, to: now) ?? now.addingTimeInterval(4 * 3600)
            completion(Timeline(entries: [LockScreenEntry(date: now, data: data)], policy: .after(next)))
        }
    }
}

struct LockScreenBudgetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LockScreenEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                Gauge(value: min(1, entry.data.consumedFraction ?? 0)) {
                    Icon("savings", size: 12)
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .widgetAccentable()
            case .accessoryInline:
                Text(entry.data.remainingText.map { "남은 예산 \($0)" } ?? "예산 미설정")
            default:
                EmptyView()
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

struct LockScreenBudgetWidget: Widget {
    let kind = "WadeMoneyLockScreenBudgetWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenProvider()) { entry in
            LockScreenBudgetWidgetView(entry: entry)
        }
        .configurationDisplayName("남은 예산")
        .description("이달 남은 예산을 잠금화면에서 바로 봐요.")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

#Preview(as: .accessoryCircular) {
    LockScreenBudgetWidget()
} timeline: {
    LockScreenEntry(date: .now, data: .init(consumedFraction: 0.42, remainingText: "840,000원"))
}
```

`WadeMoneyWidgetsExtension/WadeMoneyWidgetsBundle.swift` 수정:

```swift
import WidgetKit
import SwiftUI

@main
struct WadeMoneyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SummaryWidget()
        QuickRecordWidget()
        LockScreenBudgetWidget()
    }
}
```

주의: 잠금화면 액세서리 위젯은 시스템이 강제로 단색(사용자가 고른 잠금화면 틴트)으로 렌더링한다 — `WadeColors` 팔레트를 여기 적용하지 않는다(적용해도 시스템이 무시함). `Icon`/`Gauge`/`Text`만 사용하고 `.widgetAccentable()`로 강조할 부분만 표시한다.

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodegen generate && xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`. "Test run with 93 tests ... passed"(91 + 신규 2개) 확인.

- [ ] **Step 5: 커밋**

```
git add WadeMoney/Widgets/ WadeMoneyWidgetsExtension/ WadeMoneyTests/
git commit -m "feat(widgets): add lock screen accessory widget (circular + inline)"
```

---

### Task 5: 위젯 새로고침 트리거

거래·예산·카테고리가 바뀌면 위젯이 다음 갱신 주기(최대 4~12시간)를 기다리지 않고 즉시 새로고침되도록 앱 쪽 쓰기 경로에 `WidgetCenter` 리로드를 연결한다.

**Files:**
- Modify: `WadeMoney/Stores/LedgerRepository.swift`
- Modify: `WadeMoney/Stores/SettingsStore.swift`
- Modify: `WadeMoney/Stores/CategoryStore.swift`
- Test: 기존 `LedgerHistoryTests.swift`/`SettingsWriteTests.swift`/`CategoryStoreTests.swift`는 변경 없음(리로드 호출은 부작용이라 직접 단위 테스트 대상이 아님) — 대신 컴파일+기존 테스트 그린 유지로 검증한다.

**Interfaces:** 없음(각 저장소의 기존 쓰기 메서드 내부에 한 줄 추가).

- [ ] **Step 1: 구현**

세 파일 모두 상단에 `import WidgetKit` 추가 후, 각 쓰기 메서드의 `try context.save()` 다음 줄에 `WidgetCenter.shared.reloadAllTimelines()`를 추가한다.

`LedgerRepository.swift` — `addTransaction`/`updateTransaction`/`deleteTransaction` 세 곳:

```swift
import Foundation
import SwiftData
import WidgetKit
import WadeMoneyCore

...

    func addTransaction(...) throws {
        ...
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func deleteTransaction(id: UUID) throws {
        if let model = ... {
            context.delete(model)
            try context.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func updateTransaction(...) throws {
        ...
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
```

`SettingsStore.swift` — `setMonthlyBudget`/`setMonthStartDay` 두 곳(`setAIEnabled`은 위젯 표시와 무관하므로 제외):

```swift
import Foundation
import SwiftData
import WidgetKit
import WadeMoneyCore

...

    func setMonthlyBudget(_ amount: Decimal, for ym: YearMonth) throws {
        ...
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func setMonthStartDay(_ day: Int) throws {
        ...
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
```

`CategoryStore.swift` — `add`/`update`/`archive`/`restore`/`reorder` 다섯 곳(빠른 기록 위젯의 칩 목록에 영향):

```swift
import Foundation
import SwiftData
import WidgetKit
import WadeMoneyCore

...
    // 각 메서드의 try context.save() 다음 줄에 WidgetCenter.shared.reloadAllTimelines() 추가
```

- [ ] **Step 2: 빌드 + 전체 테스트 그린 확인**

Run: `xcodegen generate && xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`. 기존 93개 테스트가 그대로 통과해야 한다(이 태스크는 신규 로직 없음 — 부작용 호출 추가만).

주의: `WidgetCenter.shared.reloadAllTimelines()`는 위젯이 실제로 등록/설치돼 있지 않아도(홈 화면에 추가 안 한 상태) 예외 없이 조용히 아무 일도 하지 않는다 — 테스트 환경(인메모리 컨테이너, 위젯 미설치)에서 호출돼도 안전하다는 것을 확인만 하고 넘어간다(별도 모킹 불필요).

- [ ] **Step 3: 커밋**

```
git add WadeMoney/Stores/
git commit -m "feat(widgets): reload widget timelines after transaction/budget/category writes"
```

---

## Final Review 가이드 (서브에이전트 주도 실행 시)

전체 브랜치 리뷰(opus)에서 특히 아래를 확인한다:
- 위젯 확장이 SwiftData에 **쓰기**를 시도하는 코드가 없는지(`context.save()`가 위젯 타깃 전용 파일에 없는지) — 읽기 전용 원칙 위반 여부.
- `WidgetPersistence.makeContainer()`가 `cloudKitDatabase`를 지정하지 않는지(위젯이 직접 CloudKit에 접근하지 않는지).
- App Group 미가용 시(미서명 시뮬레이터) 위젯이 크래시 없이 빈 상태로 폴백하는지 — `PersistenceController`의 기존 3단계 폴백과 원칙이 일치하는지.
- Siri/App Intents/Shortcuts 관련 코드나 import가 전혀 없는지(사용자가 명시적으로 범위 제외).
- `WadeMoneyWidgetsExtension` 타깃의 `sources`에 `WadeMoney/AI`(FoundationModels 의존)나 `WadeMoney/Screens`(앱 전용 화면)가 실수로 포함되지 않았는지 — 포함됐다면 불필요한 빌드 의존성·잠재적 `@main` 충돌 위험.
- 딥링크로 연 빠른 입력 시트에서 저장/취소 후 `quickAddCategoryID`가 초기화돼 다음 FAB 탭에 잔존 상태가 새지 않는지.
- 5개 태스크 누적 테스트 수가 실제로 93(82 + 2 + 7 + 2 + 0)과 일치하는지.
