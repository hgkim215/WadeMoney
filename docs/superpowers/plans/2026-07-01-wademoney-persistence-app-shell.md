# WadeMoney — 영속화 & 앱 셸 Implementation Plan (2/5)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iOS 앱 프로젝트를 세우고, SwiftData 영속화 계층(CloudKit 동기화 포함)을 `WadeMoneyCore` 계산 엔진과 매핑으로 연결해, 화면(계획 3)이 소비할 데이터 접근 API를 완성한다.

**Architecture:** XcodeGen으로 생성한 Xcode 프로젝트(app + unit test 타깃). SwiftData `@Model`(CloudKit 호환)을 순수 값 타입(`TransactionRecord` 등)으로 매핑하는 얇은 계층을 두고, `@MainActor` 저장소(`LedgerRepository`)가 `ModelContext`를 감싸 엔진을 호출한다. 앰비언트 시간(`Date()`/`Calendar.current`)은 이 계층에서만 주입한다 — 엔진은 계속 순수하게 유지.

**Tech Stack:** Swift 6.3, XcodeGen 2.45+, SwiftUI, SwiftData, CloudKit, Swift Testing, 로컬 SPM 의존성 `WadeMoneyCore`, iOS 26 시뮬레이터(iPhone 17 Pro).

## Global Constraints

- **Bundle ID**: `com.kimhyeongi.WadeMoney` · **App Group**: `group.com.kimhyeongi.WadeMoney` · **iCloud 컨테이너**: `iCloud.com.kimhyeongi.WadeMoney`. 이 세 문자열은 여러 파일에 반복되므로 정확히 일치시킨다.
- **최소 배포 타깃**: iOS 26.0. Swift 6.
- **CloudKit 호환 `@Model` 규칙(엄수)**: 모든 저장 프로퍼티는 기본값을 갖거나 옵셔널. `@Attribute(.unique)` 금지. 모든 관계는 옵셔널. enum은 원시값(String) 프로퍼티로 저장.
- **금액은 `Decimal`**(SwiftData 지원). 원 단위, 통화 포매팅은 이 계획 범위 밖(화면 계획).
- **테스트는 인메모리·비-CloudKit 컨테이너**(`isStoredInMemoryOnly: true`, `cloudKitDatabase` 미지정)로 시뮬레이터에서 실행. **실제 CloudKit 동기화 검증은 실기기 + 유료 Apple Developer 계정 필요** — 자동 스위트 밖의 수동 단계로 남긴다.
- **엔진은 앰비언트 시간 금지 원칙 유지**: 저장소/서비스가 `now: Date`와 `Calendar`를 엔진에 주입한다. `@Model`·매핑·엔진에는 `Date()`/`Calendar.current` 호출을 넣지 않는다(주입 지점은 저장소의 프로덕션 기본값뿐).
- **빌드/테스트 명령**(서명 없이): 프로젝트 루트에서
  `xcodegen generate` → `xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
- 매핑·시드·저장소 로직은 `WadeMoneyCore`의 값 타입과 계산 함수를 재사용한다(중복 금지). 기본 카테고리 8종의 아이콘·색·순서는 디자인 시스템 §6을 그대로 따른다.
- 커밋은 자주. `.build/`, `*.xcodeproj`(생성물), `DerivedData/`는 추적 금지 — Task 1에서 `.gitignore` 확장.

---

### Task 1: XcodeGen 프로젝트 스캐폴드 + 빌드되는 빈 앱

**Files:**
- Create: `project.yml`
- Create: `WadeMoney/WadeMoneyApp.swift`
- Create: `WadeMoney/RootView.swift`
- Create: `WadeMoney/WadeMoney.entitlements`
- Create: `WadeMoney/Constants.swift`
- Create: `WadeMoneyTests/SmokeTests.swift`
- Modify: `.gitignore` (루트)

**Interfaces:**
- Consumes: `WadeMoneyCore`(로컬 패키지)
- Produces:
  - `enum AppIDs { static let appGroup: String; static let iCloudContainer: String }`
  - 빌드·기동되는 앱 타깃 `WadeMoney` + 테스트 타깃 `WadeMoneyTests`. 스킴 `WadeMoney`.

- [ ] **Step 1: `.gitignore` 확장**

루트 `.gitignore`에 다음 줄을 추가(이미 있는 줄은 중복 추가하지 말 것):

```
# Xcode / build
*.xcodeproj
DerivedData/
build/
*.xcuserstate
.swiftpm/
```

- [ ] **Step 2: XcodeGen 프로젝트 명세 작성**

`project.yml`:

```yaml
name: WadeMoney
options:
  bundleIdPrefix: com.kimhyeongi
  deploymentTarget:
    iOS: "26.0"
  developmentLanguage: ko
packages:
  WadeMoneyCore:
    path: WadeMoneyCore
settings:
  base:
    MARKETING_VERSION: "1.0"
    CURRENT_PROJECT_VERSION: "1"
    SWIFT_VERSION: "6.0"
    GENERATE_INFOPLIST_FILE: "YES"
    SWIFT_EMIT_LOC_STRINGS: "YES"
targets:
  WadeMoney:
    type: application
    platform: iOS
    sources:
      - WadeMoney
    dependencies:
      - package: WadeMoneyCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.kimhyeongi.WadeMoney
        CODE_SIGN_ENTITLEMENTS: WadeMoney/WadeMoney.entitlements
        INFOPLIST_KEY_CFBundleDisplayName: WadeMoney
        INFOPLIST_KEY_UILaunchScreen_Generation: "YES"
        INFOPLIST_KEY_UISupportedInterfaceOrientations: UIInterfaceOrientationPortrait
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
        WadeMoneyTests: [test]
    test:
      targets:
        - WadeMoneyTests
```

- [ ] **Step 3: 엔타이틀먼트 작성**

`WadeMoney/WadeMoney.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.kimhyeongi.WadeMoney</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.kimhyeongi.WadeMoney</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 4: 상수·앱 엔트리·루트 뷰 작성**

`WadeMoney/Constants.swift`:

```swift
import Foundation

enum AppIDs {
    static let appGroup = "group.com.kimhyeongi.WadeMoney"
    static let iCloudContainer = "iCloud.com.kimhyeongi.WadeMoney"
}
```

`WadeMoney/WadeMoneyApp.swift`:

```swift
import SwiftUI

@main
struct WadeMoneyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

`WadeMoney/RootView.swift`:

```swift
import SwiftUI

struct RootView: View {
    var body: some View {
        Text("WadeMoney")
            .font(.largeTitle.bold())
    }
}

#Preview {
    RootView()
}
```

- [ ] **Step 5: 스모크 테스트 작성**

`WadeMoneyTests/SmokeTests.swift`:

```swift
import Testing
@testable import WadeMoney

struct SmokeTests {
    @Test func appIDsAreConfigured() {
        #expect(AppIDs.appGroup == "group.com.kimhyeongi.WadeMoney")
        #expect(AppIDs.iCloudContainer == "iCloud.com.kimhyeongi.WadeMoney")
    }
}
```

- [ ] **Step 6: 프로젝트 생성 후 테스트가 실패→통과하는지 확인**

Run:
```bash
cd /Users/mac/Documents/Projects/WadeMoney
xcodegen generate
xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```
Expected: 빌드 성공 + `SmokeTests` PASS(1 test). 앱과 테스트 타깃이 컴파일되고 `WadeMoneyCore`가 링크됨.

> 만약 `iPhone 17 Pro` 시뮬레이터가 없으면 `xcrun simctl list devices available | grep iPhone`로 사용 가능한 이름을 찾아 `-destination`에 넣는다.

- [ ] **Step 7: 커밋**

```bash
git add project.yml WadeMoney WadeMoneyTests .gitignore
git commit -m "feat(app): scaffold WadeMoney iOS app via XcodeGen (App Group + CloudKit entitlements)"
```

---

### Task 2: SwiftData `@Model` 계층 (CloudKit 호환)

**Files:**
- Create: `WadeMoney/Models/CategoryModel.swift`
- Create: `WadeMoney/Models/TransactionModel.swift`
- Create: `WadeMoney/Models/MonthlyBudgetModel.swift`
- Create: `WadeMoney/Models/AppSettingsModel.swift`
- Test: `WadeMoneyTests/ModelPersistenceTests.swift`

**Interfaces:**
- Consumes: SwiftData
- Produces (모든 클래스 `final`, `@Model`):
  - `CategoryModel { id: UUID; name: String; iconName: String; colorHex: String; sortOrder: Int; isArchived: Bool; transactions: [TransactionModel]? }`
  - `TransactionModel { id: UUID; amount: Decimal; typeRaw: String; category: CategoryModel?; memo: String?; date: Date; createdAt: Date }` + `var type: TransactionKind { get set }`
  - `MonthlyBudgetModel { id: UUID; effectiveYear: Int; effectiveMonth: Int; amount: Decimal }`
  - `AppSettingsModel { id: UUID; monthStartDay: Int; aiEnabled: Bool }`
  - `enum TransactionKind: String { case expense, income }`

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/ModelPersistenceTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
@testable import WadeMoney

@MainActor
struct ModelPersistenceTests {
    /// 인메모리·비-CloudKit 컨테이너 (시뮬레이터에서 CloudKit 없이 동작).
    func makeContainer() throws -> ModelContainer {
        let schema = Schema([CategoryModel.self, TransactionModel.self, MonthlyBudgetModel.self, AppSettingsModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test func insertsAndFetchesTransactionWithCategory() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let cafe = CategoryModel(name: "카페", iconName: "local_cafe", colorHex: "#C4924E", sortOrder: 1)
        ctx.insert(cafe)
        let tx = TransactionModel(amount: 4800, type: .expense, category: cafe,
                                  memo: "아메리카노", date: Date(timeIntervalSince1970: 1_000))
        ctx.insert(tx)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<TransactionModel>())
        #expect(fetched.count == 1)
        #expect(fetched[0].amount == 4800)
        #expect(fetched[0].type == .expense)
        #expect(fetched[0].category?.name == "카페")
    }

    @Test func typeRawMapsToTransactionKind() throws {
        let tx = TransactionModel(amount: 100, type: .income, category: nil,
                                  memo: nil, date: Date(timeIntervalSince1970: 0))
        #expect(tx.typeRaw == "income")
        tx.type = .expense
        #expect(tx.typeRaw == "expense")
        // 알 수 없는 원시값은 지출로 폴백
        tx.typeRaw = "garbage"
        #expect(tx.type == .expense)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
Expected: 컴파일 실패 — `cannot find 'CategoryModel' in scope` 등.

- [ ] **Step 3: 카테고리·거래 종류 모델 작성**

`WadeMoney/Models/CategoryModel.swift`:

```swift
import Foundation
import SwiftData

@Model
final class CategoryModel {
    var id: UUID = UUID()
    var name: String = ""
    var iconName: String = "category"
    var colorHex: String = "#A69B8C"
    var sortOrder: Int = 0
    var isArchived: Bool = false

    // CloudKit 요구: to-many 관계는 옵셔널.
    @Relationship(deleteRule: .nullify, inverse: \TransactionModel.category)
    var transactions: [TransactionModel]?

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String,
        colorHex: String,
        sortOrder: Int,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.isArchived = isArchived
    }
}
```

`WadeMoney/Models/TransactionModel.swift`:

```swift
import Foundation
import SwiftData

enum TransactionKind: String, Sendable {
    case expense
    case income
}

@Model
final class TransactionModel {
    var id: UUID = UUID()
    var amount: Decimal = 0
    /// 원시 저장값. `type`으로 접근할 것.
    var typeRaw: String = TransactionKind.expense.rawValue
    @Relationship(deleteRule: .nullify)
    var category: CategoryModel?
    var memo: String?
    var date: Date = Date(timeIntervalSince1970: 0)
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    var type: TransactionKind {
        get { TransactionKind(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        amount: Decimal,
        type: TransactionKind = .expense,
        category: CategoryModel?,
        memo: String?,
        date: Date,
        createdAt: Date = Date(timeIntervalSince1970: 0)
    ) {
        self.id = id
        self.amount = amount
        self.typeRaw = type.rawValue
        self.category = category
        self.memo = memo
        self.date = date
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 4: 예산·설정 모델 작성**

`WadeMoney/Models/MonthlyBudgetModel.swift`:

```swift
import Foundation
import SwiftData

@Model
final class MonthlyBudgetModel {
    var id: UUID = UUID()
    var effectiveYear: Int = 0
    var effectiveMonth: Int = 1   // 1...12, 예산월의 시작 달(=예산월 시작일의 달)
    var amount: Decimal = 0

    init(id: UUID = UUID(), effectiveYear: Int, effectiveMonth: Int, amount: Decimal) {
        self.id = id
        self.effectiveYear = effectiveYear
        self.effectiveMonth = effectiveMonth
        self.amount = amount
    }
}
```

`WadeMoney/Models/AppSettingsModel.swift`:

```swift
import Foundation
import SwiftData

@Model
final class AppSettingsModel {
    var id: UUID = UUID()
    var monthStartDay: Int = 1
    var aiEnabled: Bool = true

    init(id: UUID = UUID(), monthStartDay: Int = 1, aiEnabled: Bool = true) {
        self.id = id
        self.monthStartDay = monthStartDay
        self.aiEnabled = aiEnabled
    }
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `xcodebuild test ... CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
Expected: `ModelPersistenceTests` 2 tests PASS, `SmokeTests` 1 test PASS.

- [ ] **Step 6: 커밋**

```bash
git add WadeMoney/Models WadeMoneyTests/ModelPersistenceTests.swift
git commit -m "feat(app): add CloudKit-compatible SwiftData models"
```

---

### Task 3: 매핑 계층 (`@Model` ↔ Core 값 타입)

**Files:**
- Create: `WadeMoney/Mapping/ModelMapping.swift`
- Test: `WadeMoneyTests/ModelMappingTests.swift`

**Interfaces:**
- Consumes: `WadeMoneyCore`(`TransactionRecord`, `CategoryRef`, `BudgetSnapshot`, `YearMonth`, `EngineSettings`, `TransactionType`), Task 2 모델
- Produces (모두 `WadeMoneyCore` 값 타입 반환, 순수 함수):
  - `extension TransactionModel { func toRecord() -> TransactionRecord }`
  - `extension CategoryModel { func toRef() -> CategoryRef }`
  - `extension MonthlyBudgetModel { func toSnapshot() -> BudgetSnapshot }`
  - `extension AppSettingsModel { func toEngineSettings() -> EngineSettings }`
  - `enum KindMapping { static func core(_ k: TransactionKind) -> TransactionType; static func model(_ t: TransactionType) -> TransactionKind }`

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/ModelMappingTests.swift`:

```swift
import Foundation
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct ModelMappingTests {
    @Test func transactionModelMapsToRecord() {
        let cat = CategoryModel(name: "식비", iconName: "restaurant", colorHex: "#E28A4E", sortOrder: 0)
        let tx = TransactionModel(amount: 9000, type: .expense, category: cat,
                                  memo: "점심", date: Date(timeIntervalSince1970: 500),
                                  createdAt: Date(timeIntervalSince1970: 400))
        let rec = tx.toRecord()
        #expect(rec.amount == 9000)
        #expect(rec.type == .expense)
        #expect(rec.categoryID == cat.id)
        #expect(rec.memo == "점심")
        #expect(rec.date == Date(timeIntervalSince1970: 500))
    }

    @Test func incomeMapsWithNilCategory() {
        let tx = TransactionModel(amount: 45000, type: .income, category: nil,
                                  memo: "중고거래", date: Date(timeIntervalSince1970: 0))
        let rec = tx.toRecord()
        #expect(rec.type == .income)
        #expect(rec.categoryID == nil)
    }

    @Test func categoryModelMapsToRef() {
        let cat = CategoryModel(name: "카페", iconName: "local_cafe", colorHex: "#C4924E",
                                sortOrder: 2, isArchived: true)
        let ref = cat.toRef()
        #expect(ref.id == cat.id)
        #expect(ref.name == "카페")
        #expect(ref.iconName == "local_cafe")
        #expect(ref.colorHex == "#C4924E")
        #expect(ref.sortOrder == 2)
        #expect(ref.isArchived == true)
    }

    @Test func budgetModelMapsToSnapshot() {
        let b = MonthlyBudgetModel(effectiveYear: 2026, effectiveMonth: 7, amount: 1_300_000)
        let snap = b.toSnapshot()
        #expect(snap.effectiveMonth == YearMonth(year: 2026, month: 7))
        #expect(snap.amount == 1_300_000)
    }

    @Test func settingsModelMapsToEngineSettings() {
        let s = AppSettingsModel(monthStartDay: 25, aiEnabled: false)
        let es = s.toEngineSettings()
        #expect(es.monthStartDay == 25)
        #expect(es.aiEnabled == false)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ... CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
Expected: 컴파일 실패 — `value of type 'TransactionModel' has no member 'toRecord'`.

- [ ] **Step 3: 매핑 구현 작성**

`WadeMoney/Mapping/ModelMapping.swift`:

```swift
import Foundation
import WadeMoneyCore

enum KindMapping {
    static func core(_ k: TransactionKind) -> TransactionType {
        switch k {
        case .expense: return .expense
        case .income: return .income
        }
    }
    static func model(_ t: TransactionType) -> TransactionKind {
        switch t {
        case .expense: return .expense
        case .income: return .income
        }
    }
}

extension TransactionModel {
    func toRecord() -> TransactionRecord {
        TransactionRecord(
            id: id,
            amount: amount,
            type: KindMapping.core(type),
            categoryID: category?.id,
            memo: memo,
            date: date,
            createdAt: createdAt
        )
    }
}

extension CategoryModel {
    func toRef() -> CategoryRef {
        CategoryRef(
            id: id,
            name: name,
            iconName: iconName,
            colorHex: colorHex,
            sortOrder: sortOrder,
            isArchived: isArchived
        )
    }
}

extension MonthlyBudgetModel {
    func toSnapshot() -> BudgetSnapshot {
        BudgetSnapshot(
            effectiveMonth: YearMonth(year: effectiveYear, month: effectiveMonth),
            amount: amount
        )
    }
}

extension AppSettingsModel {
    func toEngineSettings() -> EngineSettings {
        EngineSettings(monthStartDay: monthStartDay, aiEnabled: aiEnabled)
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild test ... CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
Expected: `ModelMappingTests` 5 tests PASS (+ 기존 3).

- [ ] **Step 5: 커밋**

```bash
git add WadeMoney/Mapping WadeMoneyTests/ModelMappingTests.swift
git commit -m "feat(app): map SwiftData models to WadeMoneyCore value types"
```

---

### Task 4: `ModelContainer` 팩토리 (앱 CloudKit + 테스트 인메모리)

**Files:**
- Create: `WadeMoney/Persistence/PersistenceController.swift`
- Modify: `WadeMoney/WadeMoneyApp.swift`
- Test: `WadeMoneyTests/PersistenceControllerTests.swift`

**Interfaces:**
- Consumes: SwiftData, Task 2 모델, `AppIDs`
- Produces:
  - `enum PersistenceController { static let sharedSchema: Schema; static func makeAppContainer() throws -> ModelContainer; static func makeInMemoryContainer() throws -> ModelContainer }`
  - `makeAppContainer`: App Group + CloudKit(`.private`) 백엔드. `makeInMemoryContainer`: 인메모리·비-CloudKit(테스트용).

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/PersistenceControllerTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
@testable import WadeMoney

@MainActor
struct PersistenceControllerTests {
    @Test func inMemoryContainerInsertsAndFetches() throws {
        let container = try PersistenceController.makeInMemoryContainer()
        let ctx = container.mainContext
        ctx.insert(AppSettingsModel(monthStartDay: 1))
        try ctx.save()
        let count = try ctx.fetchCount(FetchDescriptor<AppSettingsModel>())
        #expect(count == 1)
    }

    @Test func schemaCoversAllModels() {
        // 스키마에 4개 엔티티가 모두 등록됐는지 확인.
        let names = Set(PersistenceController.sharedSchema.entities.map(\.name))
        #expect(names.isSuperset(of: ["CategoryModel", "TransactionModel", "MonthlyBudgetModel", "AppSettingsModel"]))
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ... CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
Expected: 컴파일 실패 — `cannot find 'PersistenceController' in scope`.

- [ ] **Step 3: 영속화 컨트롤러 구현**

`WadeMoney/Persistence/PersistenceController.swift`:

```swift
import Foundation
import SwiftData

enum PersistenceController {
    static let sharedSchema = Schema([
        CategoryModel.self,
        TransactionModel.self,
        MonthlyBudgetModel.self,
        AppSettingsModel.self,
    ])

    /// 프로덕션: App Group 공유 저장소 + CloudKit 개인 DB 동기화.
    /// (실제 동기화는 유료 Apple Developer 계정 + 프로비저닝된 iCloud 컨테이너 + 실기기 필요.)
    static func makeAppContainer() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: sharedSchema,
            groupContainer: .identifier(AppIDs.appGroup),
            cloudKitDatabase: .private(AppIDs.iCloudContainer)
        )
        return try ModelContainer(for: sharedSchema, configurations: [config])
    }

    /// 테스트/프리뷰: 인메모리, CloudKit 없음.
    static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: sharedSchema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: sharedSchema, configurations: [config])
    }
}
```

- [ ] **Step 4: 앱 엔트리에 컨테이너 연결**

`WadeMoney/WadeMoneyApp.swift`를 다음으로 교체:

```swift
import SwiftUI
import SwiftData

@main
struct WadeMoneyApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try PersistenceController.makeAppContainer()
        } catch {
            // 최초 마이그레이션/프로비저닝 실패 시 로컬 인메모리로 폴백(앱은 뜬다).
            container = try! PersistenceController.makeInMemoryContainer()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `xcodebuild test ... CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
Expected: `PersistenceControllerTests` 2 tests PASS (+ 기존). 앱 타깃도 정상 컴파일.

> 참고: 테스트는 `makeInMemoryContainer`만 사용한다. `makeAppContainer`(CloudKit)는 시뮬레이터·CI에서 계정 없이는 런타임 동작이 검증되지 않으므로 자동 스위트에서 인스턴스화하지 않는다.

- [ ] **Step 6: 커밋**

```bash
git add WadeMoney/Persistence WadeMoney/WadeMoneyApp.swift WadeMoneyTests/PersistenceControllerTests.swift
git commit -m "feat(app): add ModelContainer factory (App Group + CloudKit / in-memory)"
```

---

### Task 5: 기본 카테고리 시드 (멱등)

**Files:**
- Create: `WadeMoney/Persistence/CategorySeeder.swift`
- Test: `WadeMoneyTests/CategorySeederTests.swift`

**Interfaces:**
- Consumes: SwiftData, `CategoryModel`
- Produces:
  - `enum CategorySeeder { static let defaults: [SeedCategory]; static func seedIfNeeded(_ context: ModelContext) throws }`
  - `struct SeedCategory { let name: String; let iconName: String; let colorHex: String }`
  - 최초 1회만 8개 삽입. 카테고리가 이미 하나라도 있으면 아무것도 안 함(멱등).

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/CategorySeederTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
@testable import WadeMoney

@MainActor
struct CategorySeederTests {
    func ctx() throws -> ModelContext {
        try PersistenceController.makeInMemoryContainer().mainContext
    }

    @Test func seedsEightDefaultsOnEmptyStore() throws {
        let c = try ctx()
        try CategorySeeder.seedIfNeeded(c)
        let cats = try c.fetch(FetchDescriptor<CategoryModel>())
        #expect(cats.count == 8)
        #expect(Set(cats.map(\.name)) == ["식비", "카페", "교통", "쇼핑", "문화", "의료", "주거", "기타"])
        // 순서(sortOrder)가 0..7로 배정됨
        #expect(Set(cats.map(\.sortOrder)) == Set(0...7))
    }

    @Test func seedingIsIdempotent() throws {
        let c = try ctx()
        try CategorySeeder.seedIfNeeded(c)
        try CategorySeeder.seedIfNeeded(c)
        let count = try c.fetchCount(FetchDescriptor<CategoryModel>())
        #expect(count == 8)
    }

    @Test func firstCategoryMatchesDesignSpec() throws {
        let c = try ctx()
        try CategorySeeder.seedIfNeeded(c)
        let food = try c.fetch(FetchDescriptor<CategoryModel>())
            .first { $0.name == "식비" }
        #expect(food?.iconName == "restaurant")
        #expect(food?.colorHex == "#E28A4E")
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ... CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
Expected: 컴파일 실패 — `cannot find 'CategorySeeder' in scope`.

- [ ] **Step 3: 시더 구현 (디자인 시스템 §6 값 그대로)**

`WadeMoney/Persistence/CategorySeeder.swift`:

```swift
import Foundation
import SwiftData

struct SeedCategory {
    let name: String
    let iconName: String
    let colorHex: String
}

enum CategorySeeder {
    /// 디자인 시스템 §6 기본 카테고리(노출 순서와 무관한 시드 순서 = sortOrder 0..7).
    static let defaults: [SeedCategory] = [
        SeedCategory(name: "식비", iconName: "restaurant",       colorHex: "#E28A4E"),
        SeedCategory(name: "카페", iconName: "local_cafe",        colorHex: "#C4924E"),
        SeedCategory(name: "교통", iconName: "directions_bus",    colorHex: "#6F9FD8"),
        SeedCategory(name: "쇼핑", iconName: "shopping_bag",      colorHex: "#DB84AE"),
        SeedCategory(name: "문화", iconName: "movie",             colorHex: "#D8AE45"),
        SeedCategory(name: "의료", iconName: "medical_services",  colorHex: "#5DB794"),
        SeedCategory(name: "주거", iconName: "home",              colorHex: "#8E82CE"),
        SeedCategory(name: "기타", iconName: "category",          colorHex: "#A69B8C"),
    ]

    /// 카테고리가 하나도 없을 때만 기본 8종을 삽입한다(멱등).
    static func seedIfNeeded(_ context: ModelContext) throws {
        let existing = try context.fetchCount(FetchDescriptor<CategoryModel>())
        guard existing == 0 else { return }

        for (index, seed) in defaults.enumerated() {
            context.insert(CategoryModel(
                name: seed.name,
                iconName: seed.iconName,
                colorHex: seed.colorHex,
                sortOrder: index
            ))
        }
        try context.save()
    }
}
```

- [ ] **Step 4: 앱 최초 실행 시 시드 호출**

`WadeMoney/WadeMoneyApp.swift`의 `init()` 끝(컨테이너 확정 후)에 시드 호출을 추가한다. `init()`를 다음으로 교체:

```swift
    init() {
        let resolved: ModelContainer
        do {
            resolved = try PersistenceController.makeAppContainer()
        } catch {
            resolved = try! PersistenceController.makeInMemoryContainer()
        }
        container = resolved
        try? CategorySeeder.seedIfNeeded(resolved.mainContext)
    }
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `xcodebuild test ... CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
Expected: `CategorySeederTests` 3 tests PASS (+ 기존).

- [ ] **Step 6: 커밋**

```bash
git add WadeMoney/Persistence/CategorySeeder.swift WadeMoney/WadeMoneyApp.swift WadeMoneyTests/CategorySeederTests.swift
git commit -m "feat(app): seed default categories on first launch (idempotent)"
```

---

### Task 6: 설정·예산 저장소 (싱글턴 설정 + 예산 스냅샷)

**Files:**
- Create: `WadeMoney/Stores/SettingsStore.swift`
- Test: `WadeMoneyTests/SettingsStoreTests.swift`

**Interfaces:**
- Consumes: SwiftData, `WadeMoneyCore`(`BudgetBook`, `BudgetSnapshot`, `EngineSettings`, `YearMonth`), Task 3 매핑
- Produces (`@MainActor final class`):
  - `SettingsStore(context: ModelContext)`
  - `func settings() throws -> EngineSettings` — 없으면 기본 레코드 생성 후 반환
  - `func settingsModel() throws -> AppSettingsModel` — 싱글턴 fetch-or-create
  - `func setMonthlyBudget(_ amount: Decimal, for ym: YearMonth) throws` — 같은 (년,월) 있으면 갱신, 없으면 삽입
  - `func budgetBook() throws -> BudgetBook`

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/SettingsStoreTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct SettingsStoreTests {
    func store() throws -> SettingsStore {
        let ctx = try PersistenceController.makeInMemoryContainer().mainContext
        return SettingsStore(context: ctx)
    }

    @Test func settingsCreatesSingletonWithDefaults() throws {
        let s = try store()
        let es = try s.settings()
        #expect(es.monthStartDay == 1)
        #expect(es.aiEnabled == true)
        // 두 번째 호출도 새 레코드를 만들지 않음
        _ = try s.settings()
        let model = try s.settingsModel()
        #expect(model.monthStartDay == 1)
    }

    @Test func setMonthlyBudgetInsertsThenUpdatesSameMonth() throws {
        let s = try store()
        try s.setMonthlyBudget(1_000_000, for: YearMonth(year: 2026, month: 7))
        try s.setMonthlyBudget(1_300_000, for: YearMonth(year: 2026, month: 7)) // 갱신
        try s.setMonthlyBudget(1_500_000, for: YearMonth(year: 2026, month: 8)) // 신규
        let book = try s.budgetBook()
        #expect(book.amount(for: YearMonth(year: 2026, month: 7)) == 1_300_000)
        #expect(book.amount(for: YearMonth(year: 2026, month: 8)) == 1_500_000)
        #expect(book.amount(for: YearMonth(year: 2026, month: 6)) == nil)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ... CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
Expected: 컴파일 실패 — `cannot find 'SettingsStore' in scope`.

- [ ] **Step 3: 저장소 구현**

`WadeMoney/Stores/SettingsStore.swift`:

```swift
import Foundation
import SwiftData
import WadeMoneyCore

@MainActor
final class SettingsStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func settingsModel() throws -> AppSettingsModel {
        if let existing = try context.fetch(FetchDescriptor<AppSettingsModel>()).first {
            return existing
        }
        let created = AppSettingsModel()
        context.insert(created)
        try context.save()
        return created
    }

    func settings() throws -> EngineSettings {
        try settingsModel().toEngineSettings()
    }

    func setMonthlyBudget(_ amount: Decimal, for ym: YearMonth) throws {
        let year = ym.year
        let month = ym.month
        let descriptor = FetchDescriptor<MonthlyBudgetModel>(
            predicate: #Predicate { $0.effectiveYear == year && $0.effectiveMonth == month }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.amount = amount
        } else {
            context.insert(MonthlyBudgetModel(effectiveYear: year, effectiveMonth: month, amount: amount))
        }
        try context.save()
    }

    func budgetBook() throws -> BudgetBook {
        let snapshots = try context.fetch(FetchDescriptor<MonthlyBudgetModel>())
            .map { $0.toSnapshot() }
        return BudgetBook(snapshots)
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild test ... CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
Expected: `SettingsStoreTests` 2 tests PASS (+ 기존).

- [ ] **Step 5: 커밋**

```bash
git add WadeMoney/Stores/SettingsStore.swift WadeMoneyTests/SettingsStoreTests.swift
git commit -m "feat(app): add SettingsStore (singleton settings + budget snapshots)"
```

---

### Task 7: 원장 저장소 + 대시보드 요약 (엔진 통합)

화면(계획 3)이 소비할 읽기 API를 완성한다. 거래 CRUD와, 한 기간의 대시보드 수치를 엔진으로 조립해 반환.

**Files:**
- Create: `WadeMoney/Stores/LedgerRepository.swift`
- Test: `WadeMoneyTests/LedgerRepositoryTests.swift`

**Interfaces:**
- Consumes: SwiftData, `WadeMoneyCore`(`PeriodCalculator`, `Aggregator`, `PaceCalculator`, `Donut`, `Projection`, `PeriodKind`, `TransactionRecord`, `CategoryRef`, `DonutSlice`, `PaceResult`), Task 3 매핑, Task 6 `SettingsStore`
- Produces (`@MainActor final class`):
  - `LedgerRepository(context: ModelContext)`
  - `func allCategories(includeArchived: Bool) throws -> [CategoryRef]`
  - `func allTransactions() throws -> [TransactionRecord]`
  - `func addTransaction(amount:type:categoryID:memo:date:) throws`
  - `func deleteTransaction(id: UUID) throws`
  - `func dashboardSummary(kind: PeriodKind, offset: Int, now: Date, calendar: Calendar) throws -> DashboardSummary`
  - `struct DashboardSummary { let period: Period; let totalExpense: Decimal; let budget: Decimal?; let remaining: Decimal?; let consumedFraction: Double?; let pace: PaceResult?; let donut: [DonutSlice]; let projected: Decimal? }`

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/LedgerRepositoryTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct LedgerRepositoryTests {
    /// 결정적 UTC 캘린더.
    var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }

    func freshRepo() throws -> (LedgerRepository, SettingsStore) {
        let ctx = try PersistenceController.makeInMemoryContainer().mainContext
        try CategorySeeder.seedIfNeeded(ctx)
        return (LedgerRepository(context: ctx), SettingsStore(context: ctx))
    }

    func categoryID(_ repo: LedgerRepository, _ name: String) throws -> UUID {
        try repo.allCategories(includeArchived: false).first { $0.name == name }!.id
    }

    @Test func addAndFetchTransaction() throws {
        let (repo, _) = try freshRepo()
        let cafe = try categoryID(repo, "카페")
        try repo.addTransaction(amount: 4800, type: .expense, categoryID: cafe, memo: "아메", date: date(2026, 7, 3))
        let all = try repo.allTransactions()
        #expect(all.count == 1)
        #expect(all[0].categoryID == cafe)
        #expect(all[0].amount == 4800)
    }

    @Test func deleteTransactionRemovesIt() throws {
        let (repo, _) = try freshRepo()
        let food = try categoryID(repo, "식비")
        try repo.addTransaction(amount: 9000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 2))
        let id = try repo.allTransactions()[0].id
        try repo.deleteTransaction(id: id)
        #expect(try repo.allTransactions().isEmpty)
    }

    @Test func dashboardSummaryComposesEngine() throws {
        let (repo, settings) = try freshRepo()
        try settings.setMonthlyBudget(1_000_000, for: YearMonth(year: 2026, month: 7))
        let food = try categoryID(repo, "식비")
        let cafe = try categoryID(repo, "카페")
        try repo.addTransaction(amount: 100_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))
        try repo.addTransaction(amount: 60_000, type: .expense, categoryID: cafe, memo: nil, date: date(2026, 7, 6))
        try repo.addTransaction(amount: 45_000, type: .income, categoryID: nil, memo: "환급", date: date(2026, 7, 7))

        let s = try repo.dashboardSummary(kind: .month, offset: 0, now: date(2026, 7, 15), calendar: utc)
        #expect(s.totalExpense == 160_000)              // 수입 45,000 제외
        #expect(s.budget == 1_000_000)
        #expect(s.remaining == 840_000)
        #expect(s.donut.count == 2)                      // 식비, 카페
        #expect(s.donut.first?.total == 100_000)         // 최대 먼저
        #expect(s.pace != nil)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ... CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
Expected: 컴파일 실패 — `cannot find 'LedgerRepository' in scope`.

- [ ] **Step 3: 저장소 구현**

`WadeMoney/Stores/LedgerRepository.swift`:

```swift
import Foundation
import SwiftData
import WadeMoneyCore

@MainActor
final class LedgerRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Reads

    func allCategories(includeArchived: Bool) throws -> [CategoryRef] {
        let models = try context.fetch(
            FetchDescriptor<CategoryModel>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        return models
            .filter { includeArchived || !$0.isArchived }
            .map { $0.toRef() }
    }

    func allTransactions() throws -> [TransactionRecord] {
        try context.fetch(FetchDescriptor<TransactionModel>())
            .map { $0.toRecord() }
    }

    // MARK: - Writes

    func addTransaction(
        amount: Decimal,
        type: TransactionKind,
        categoryID: UUID?,
        memo: String?,
        date: Date
    ) throws {
        var category: CategoryModel?
        if let categoryID {
            category = try context.fetch(
                FetchDescriptor<CategoryModel>(predicate: #Predicate { $0.id == categoryID })
            ).first
        }
        context.insert(TransactionModel(
            amount: amount,
            type: type,
            category: category,
            memo: memo,
            date: date,
            createdAt: date
        ))
        try context.save()
    }

    func deleteTransaction(id: UUID) throws {
        if let model = try context.fetch(
            FetchDescriptor<TransactionModel>(predicate: #Predicate { $0.id == id })
        ).first {
            context.delete(model)
            try context.save()
        }
    }

    // MARK: - Dashboard

    struct DashboardSummary {
        let period: Period
        let totalExpense: Decimal
        let budget: Decimal?
        let remaining: Decimal?
        let consumedFraction: Double?
        let pace: PaceResult?
        let donut: [DonutSlice]
        let projected: Decimal?
    }

    func dashboardSummary(
        kind: PeriodKind,
        offset: Int,
        now: Date,
        calendar: Calendar
    ) throws -> DashboardSummary {
        let settings = try SettingsStore(context: context).settings()
        let calc = PeriodCalculator(calendar: calendar, monthStartDay: settings.monthStartDay)
        let period = calc.period(kind, offset: offset, from: now)

        let txns = try allTransactions()
        let total = Aggregator.totalExpense(txns, in: period)

        let book = try SettingsStore(context: context).budgetBook()
        let budget: Decimal?
        switch kind {
        case .day:   budget = book.dailyAmount(on: period.start, calc: calc)
        case .month: budget = book.monthlyAmount(on: period.start, calc: calc)
        case .year:  budget = book.yearAmount(on: period.start, calc: calc)
        }

        let remaining = budget.map { $0 - total }
        let consumed: Double? = budget.flatMap { b in
            b > 0 ? (total / b).doubleValue : nil
        }

        // 페이스는 월·연에서만(일 뷰는 일예산 대비로 표시 — 화면 계층).
        let pace: PaceResult? = (kind == .day)
            ? nil
            : PaceCalculator(calc: calc).pace(kind: kind, containing: period.start, asOf: now, txns: txns)

        let donut = Donut.slices(Aggregator.totalsByCategory(txns, in: period), maxSlices: 6)

        let elapsed = calc.daysElapsed(in: period, asOf: now)
        let projected: Decimal? = (kind == .day)
            ? nil
            : Projection.projectedTotal(cumulative: total, daysElapsed: elapsed, daysInPeriod: calc.dayCount(of: period))

        return DashboardSummary(
            period: period,
            totalExpense: total,
            budget: budget,
            remaining: remaining,
            consumedFraction: consumed,
            pace: pace,
            donut: donut,
            projected: projected
        )
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild test ... CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
Expected: `LedgerRepositoryTests` 3 tests PASS (+ 기존 전체). 전체 스위트 GREEN.

- [ ] **Step 5: 커밋**

```bash
git add WadeMoney/Stores/LedgerRepository.swift WadeMoneyTests/LedgerRepositoryTests.swift
git commit -m "feat(app): add LedgerRepository with engine-composed dashboard summary"
```

---

## Self-Review (계획 작성자 확인 완료)

- **스펙 커버리지**: 데이터 모델(§4)→Task 2; 매핑→Task 3; CloudKit/App Group 동기화→Task 1(엔타이틀먼트)+Task 4(컨테이너); 카테고리 시드(디자인 §6)→Task 5; 월 예산 스냅샷(§4)→Task 6; 일/월/연 집계·페이스·도넛·예상의 데이터 조립(§5)→Task 7. **화면 렌더링·통화 포매팅·기간 라벨 문자열·AI·위젯은 이 계획 밖**(계획 3~5).
- **CloudKit 결정 반영**: 엔타이틀먼트·컨테이너 설정 포함(사용자 "지금 연결" 선택). 시뮬레이터 한계로 자동 검증은 인메모리로, 실제 동기화는 수동 단계 명시(아래).
- **플레이스홀더 스캔**: 없음. 모든 스텝에 실제 코드/명령 포함.
- **타입 일관성**: `TransactionKind`(모델) ↔ `TransactionType`(엔진)은 `KindMapping`으로만 변환. `PersistenceController.makeInMemoryContainer` 시그니처가 모든 테스트에서 일치. `DashboardSummary`는 Task 7에서 정의되고 그 안에서만 사용. `SettingsStore.budgetBook()`/`settings()`가 Task 7에서 재사용됨.
- **엔진 순수성 유지**: `Date()`/`Calendar.current`는 이 계획의 어느 소스에도 없음. 대시보드는 `now`·`calendar`를 파라미터로 받음(프로덕션 주입은 계획 3의 뷰모델이 담당).

## 수동 검증 단계 (자동 스위트 밖 — 유료 계정 필요)

CloudKit 실제 동기화는 다음이 갖춰졌을 때 실기기로 확인한다:
1. 유료 Apple Developer 계정으로 `DEVELOPMENT_TEAM` 설정(`project.yml` 또는 Xcode Signing).
2. iCloud 컨테이너 `iCloud.com.kimhyeongi.WadeMoney`와 App Group `group.com.kimhyeongi.WadeMoney`를 개발자 계정에 프로비저닝.
3. 같은 Apple ID로 로그인한 기기 2대에서 한쪽 입력이 다른 쪽에 반영되는지 확인.

## 다음 계획으로의 인터페이스

계획 3(화면)은 `@MainActor` 뷰모델에서:
- `PersistenceController.makeAppContainer()`의 `mainContext`로 `LedgerRepository`·`SettingsStore` 생성
- `now = Date()`, `calendar = .current`를 `dashboardSummary(...)`에 주입
- `DashboardSummary`·`CategoryRef`·`DonutSlice`를 통화/라벨 포매팅해 디자인 시스템 컴포넌트로 렌더
- 도넛 슬라이스의 `categoryID`를 `allCategories()`로 조인해 이름·색 표시(`isOther`는 "기타")
