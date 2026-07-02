# WadeMoney — 내역·설정·카테고리 관리 Implementation Plan (4/6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 비-AI 앱을 완성한다. 내역(필터·수정·삭제) 화면, 설정(예산·월 시작일·AI 토글·동기화 상태·CSV 내보내기) 화면, 카테고리 관리(추가·수정·아카이브·복원·재정렬) 화면을 구현하고, 거래 편집·기간별 조회·수입 노출 등 계획 3 리뷰 백로그를 반영한다.

**Architecture:** 쓰기 로직은 `@MainActor` 저장소(`LedgerRepository`·`CategoryStore`·`SettingsStore`)에, 표시·그룹핑 변환은 `@Observable` 뷰모델에 두어 단위 테스트한다. SwiftUI 화면은 뷰모델을 렌더하고 빌드+스크린샷으로 검증한다. 거래 편집은 계획 3의 빠른 입력 시트를 "편집 모드"로 일반화해 재사용한다.

**Tech Stack:** SwiftUI, `@Observable`, SwiftData, `WadeMoneyCore`, Swift Testing, XcodeGen, iOS 26 시뮬레이터.

## Global Constraints

- **범위**: 내역·설정·카테고리 관리 화면 + 이를 지원하는 저장소/뷰모델. **AI 리포트 화면·AI 인사이트·메모 다듬기는 계획 5**. 위젯은 계획 6.
- **디자인 정본**: `docs/design/app-design-specification-analysis/project/WadeMoney 가계부.dc.html`의 내역(§5.2)·설정(§5.3)·카테고리 관리(§5.4) 화면. 토큰은 디자인 시스템 문서 §1~§3, `WadeColors`/`WadeFont`/`WadeRadius`/`WadeSpacing`/`Icon`을 사용(임의 색·크기 금지).
- **통화**: `Won`으로 ₩ 정수 포매팅. 지출은 `−`, 수입은 `+`(good 색).
- **뷰모델 순수성**: `now`/`calendar` 주입. 뷰모델·저장소에 `Date()`/`Calendar.current` 직접 호출 금지(주입은 화면 진입점의 기본값에서만).
- **카테고리 삭제 = 아카이브(소프트)**: 하드 삭제 금지. 과거 거래의 카테고리 보존.
- **편집**: 빠른 입력 시트를 일반화(추가/편집 겸용). 편집 저장은 `updateTransaction`, id/createdAt 보존.
- **빌드/테스트**(서명 없이): `xcodegen generate` → `xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`. Swift Testing 결과는 "Test run with N tests ... passed" 라인으로 확인. SourceKit IDE의 "No such module" 류는 오류 아님.
- **화면 수동 검증**: 뷰 태스크는 빌드 + 시뮬레이터 스크린샷으로 확인(앱은 미서명 시뮬레이터에서 로컬 저장소로 정상 기동). 스크린샷을 디자인과 대조.
- SwiftData 테스트 헬퍼는 반드시 `ModelContainer`를 보유(미보유 시 dealloc 크래시).
- `.build/`·`*.xcodeproj`·`DerivedData/` 추적 금지. 커밋은 자주.
- 시작 테스트 수: 36 (계획 3 종료 시점). 각 태스크가 누적 증가.

---

### Task 1: 거래 편집 + 기간·필터 조회 + 수입 노출 (`LedgerRepository`)

**Files:**
- Modify: `WadeMoney/Stores/LedgerRepository.swift`
- Test: `WadeMoneyTests/LedgerHistoryTests.swift`

**Interfaces:**
- Consumes: 기존 `LedgerRepository`, `WadeMoneyCore`
- Produces (`LedgerRepository`에 추가):
  - `enum HistoryFilter: Equatable { case all; case category(UUID); case income }`
  - `func transactions(filter: HistoryFilter) throws -> [TransactionRecord]` — 필터 적용, `date` 내림차순(동일 날짜는 `createdAt` 내림차순)
  - `func transactionRecord(id: UUID) throws -> TransactionRecord?`
  - `func updateTransaction(id: UUID, amount: Decimal, type: TransactionKind, categoryID: UUID?, memo: String?, date: Date) throws`
  - `func totalIncome(in period: Period) throws -> Decimal`
  - `DashboardSummary`에 `let totalIncome: Decimal` 추가하고 `dashboardSummary`에서 채움

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/LedgerHistoryTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct LedgerHistoryTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int, _ hh: Int = 0) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d; comps.hour = hh
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

    @Test func transactionsSortedDateDescending() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비")
        try r.addTransaction(amount: 1000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 10))
        try r.addTransaction(amount: 2000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 12))
        let all = try r.transactions(filter: .all)
        #expect(all.map(\.amount) == [2000, 1000])   // 최신 먼저
        _ = c
    }

    @Test func filterByCategoryAndIncome() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비"); let cafe = try catID(r, "카페")
        try r.addTransaction(amount: 1000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 10))
        try r.addTransaction(amount: 500, type: .expense, categoryID: cafe, memo: nil, date: date(2026, 7, 11))
        try r.addTransaction(amount: 9000, type: .income, categoryID: nil, memo: "환급", date: date(2026, 7, 12))
        #expect(try r.transactions(filter: .category(food)).map(\.amount) == [1000])
        #expect(try r.transactions(filter: .income).map(\.amount) == [9000])
        #expect(try r.transactions(filter: .all).count == 3)
        _ = c
    }

    @Test func updateTransactionChangesFieldsKeepsID() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비"); let cafe = try catID(r, "카페")
        try r.addTransaction(amount: 1000, type: .expense, categoryID: food, memo: "old", date: date(2026, 7, 10))
        let id = try r.transactions(filter: .all)[0].id
        try r.updateTransaction(id: id, amount: 3000, type: .expense, categoryID: cafe, memo: "new", date: date(2026, 7, 11))
        let rec = try #require(try r.transactionRecord(id: id))
        #expect(rec.id == id)
        #expect(rec.amount == 3000)
        #expect(rec.categoryID == cafe)
        #expect(rec.memo == "new")
        _ = c
    }

    @Test func totalIncomeSumsIncomeInPeriod() throws {
        let (r, c) = try repo()
        try r.addTransaction(amount: 9000, type: .income, categoryID: nil, memo: nil, date: date(2026, 7, 5))
        try r.addTransaction(amount: 1000, type: .income, categoryID: nil, memo: nil, date: date(2026, 8, 1))
        let calc = PeriodCalculator(calendar: utc, monthStartDay: 1)
        let july = calc.period(.month, containing: date(2026, 7, 1))
        #expect(try r.totalIncome(in: july) == 9000)
        _ = c
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ... CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
Expected: 컴파일 실패 — `value of type 'LedgerRepository' has no member 'transactions'` 등.

- [ ] **Step 3: 구현 추가**

`WadeMoney/Stores/LedgerRepository.swift`에 추가(파일 상단에 `HistoryFilter` 추가, 클래스에 메서드 추가, `DashboardSummary`에 `totalIncome` 추가):

```swift
enum HistoryFilter: Equatable {
    case all
    case category(UUID)
    case income
}
```

클래스 본문에 추가:

```swift
    func transactions(filter: HistoryFilter) throws -> [TransactionRecord] {
        let records = try context.fetch(FetchDescriptor<TransactionModel>())
            .map { $0.toRecord() }
        let filtered: [TransactionRecord]
        switch filter {
        case .all:
            filtered = records
        case .income:
            filtered = records.filter { $0.type == .income }
        case .category(let id):
            filtered = records.filter { $0.type == .expense && $0.categoryID == id }
        }
        return filtered.sorted {
            if $0.date != $1.date { return $0.date > $1.date }
            return $0.createdAt > $1.createdAt
        }
    }

    func transactionRecord(id: UUID) throws -> TransactionRecord? {
        try context.fetch(FetchDescriptor<TransactionModel>(predicate: #Predicate { $0.id == id }))
            .first?.toRecord()
    }

    func updateTransaction(
        id: UUID,
        amount: Decimal,
        type: TransactionKind,
        categoryID: UUID?,
        memo: String?,
        date: Date
    ) throws {
        guard let model = try context.fetch(
            FetchDescriptor<TransactionModel>(predicate: #Predicate { $0.id == id })
        ).first else { return }
        var category: CategoryModel?
        if let categoryID {
            category = try context.fetch(
                FetchDescriptor<CategoryModel>(predicate: #Predicate { $0.id == categoryID })
            ).first
        }
        model.amount = amount
        model.type = type
        model.category = type == .income ? nil : category
        model.memo = memo
        model.date = date
        try context.save()
    }

    func totalIncome(in period: Period) throws -> Decimal {
        Aggregator.totalIncome(try allTransactions(), in: period)
    }
```

`DashboardSummary` 구조체에 `let totalIncome: Decimal` 필드를 추가하고, `dashboardSummary(...)` 반환 시 `totalIncome: Aggregator.totalIncome(txns, in: period)`를 채운다.

- [ ] **Step 4: 통과 확인 + 커밋**

전체 GREEN(기존 36 + LedgerHistoryTests 4 = 40). 기존 `LedgerRepositoryTests`의 `dashboardSummary` 호출부가 `totalIncome` 필드 추가로 깨지지 않는지 확인(구조체 필드 추가는 기존 생성 코드에 영향 없음 — `dashboardSummary` 내부에서만 생성).
```bash
git add WadeMoney/Stores/LedgerRepository.swift WadeMoneyTests/LedgerHistoryTests.swift
git commit -m "feat(app): add transaction edit, filtered history, income totals"
```

---

### Task 2: 카테고리 쓰기 API (`CategoryStore`)

**Files:**
- Create: `WadeMoney/Stores/CategoryStore.swift`
- Test: `WadeMoneyTests/CategoryStoreTests.swift`

**Interfaces:**
- Consumes: SwiftData, `CategoryModel`, `WadeMoneyCore`(`CategoryRef`)
- Produces (`@MainActor final class CategoryStore(context:)`):
  - `func active() throws -> [CategoryRef]` / `func archived() throws -> [CategoryRef]` (둘 다 `sortOrder` 오름차순)
  - `func add(name: String, iconName: String, colorHex: String) throws` — 새 `sortOrder` = 현재 최대+1
  - `func update(id: UUID, name: String, iconName: String, colorHex: String) throws`
  - `func archive(id: UUID) throws` / `func restore(id: UUID) throws`
  - `func reorder(_ orderedIDs: [UUID]) throws` — 주어진 순서대로 `sortOrder` 재배정

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/CategoryStoreTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
@testable import WadeMoney

@MainActor
struct CategoryStoreTests {
    func store() throws -> (CategoryStore, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        return (CategoryStore(context: container.mainContext), container)
    }

    @Test func addAppendsWithNextSortOrder() throws {
        let (s, c) = try store()
        let before = try s.active()
        try s.add(name: "여행", iconName: "flight", colorHex: "#4DA0C4")
        let after = try s.active()
        #expect(after.count == before.count + 1)
        let added = try #require(after.first { $0.name == "여행" })
        #expect(added.sortOrder == before.map(\.sortOrder).max()! + 1)
        _ = c
    }

    @Test func archiveAndRestoreMovesBetweenLists() throws {
        let (s, c) = try store()
        let cafe = try s.active().first { $0.name == "카페" }!.id
        try s.archive(id: cafe)
        #expect(try s.active().contains { $0.id == cafe } == false)
        #expect(try s.archived().contains { $0.id == cafe } == true)
        try s.restore(id: cafe)
        #expect(try s.active().contains { $0.id == cafe } == true)
        _ = c
    }

    @Test func updateChangesNameIconColor() throws {
        let (s, c) = try store()
        let etc = try s.active().first { $0.name == "기타" }!.id
        try s.update(id: etc, name: "기타지출", iconName: "more_horiz", colorHex: "#999999")
        let updated = try #require(try s.active().first { $0.id == etc })
        #expect(updated.name == "기타지출")
        #expect(updated.iconName == "more_horiz")
        #expect(updated.colorHex == "#999999")
        _ = c
    }

    @Test func reorderReassignsSortOrder() throws {
        let (s, c) = try store()
        let ids = try s.active().map(\.id)
        let reversed = Array(ids.reversed())
        try s.reorder(reversed)
        #expect(try s.active().map(\.id) == reversed)
        _ = c
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ...`
Expected: 컴파일 실패 — `cannot find 'CategoryStore'`.

- [ ] **Step 3: 구현 작성**

`WadeMoney/Stores/CategoryStore.swift`:

```swift
import Foundation
import SwiftData
import WadeMoneyCore

@MainActor
final class CategoryStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    private func models(archived: Bool) throws -> [CategoryModel] {
        try context.fetch(FetchDescriptor<CategoryModel>(sortBy: [SortDescriptor(\.sortOrder)]))
            .filter { $0.isArchived == archived }
    }

    func active() throws -> [CategoryRef] { try models(archived: false).map { $0.toRef() } }
    func archived() throws -> [CategoryRef] { try models(archived: true).map { $0.toRef() } }

    func add(name: String, iconName: String, colorHex: String) throws {
        let maxOrder = try context.fetch(FetchDescriptor<CategoryModel>())
            .map(\.sortOrder).max() ?? -1
        context.insert(CategoryModel(name: name, iconName: iconName, colorHex: colorHex, sortOrder: maxOrder + 1))
        try context.save()
    }

    func update(id: UUID, name: String, iconName: String, colorHex: String) throws {
        guard let m = try model(id) else { return }
        m.name = name
        m.iconName = iconName
        m.colorHex = colorHex
        try context.save()
    }

    func archive(id: UUID) throws {
        guard let m = try model(id) else { return }
        m.isArchived = true
        try context.save()
    }

    func restore(id: UUID) throws {
        guard let m = try model(id) else { return }
        m.isArchived = false
        try context.save()
    }

    func reorder(_ orderedIDs: [UUID]) throws {
        let all = try context.fetch(FetchDescriptor<CategoryModel>())
        let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        for (index, id) in orderedIDs.enumerated() {
            byID[id]?.sortOrder = index
        }
        try context.save()
    }

    private func model(_ id: UUID) throws -> CategoryModel? {
        try context.fetch(FetchDescriptor<CategoryModel>(predicate: #Predicate { $0.id == id })).first
    }
}
```

- [ ] **Step 4: 통과 확인 + 커밋**

전체 GREEN(누적 44). 커밋:
```bash
git add WadeMoney/Stores/CategoryStore.swift WadeMoneyTests/CategoryStoreTests.swift
git commit -m "feat(app): add CategoryStore CRUD (add/update/archive/restore/reorder)"
```

---

### Task 3: 설정 세터 + CSV 내보내기

**Files:**
- Modify: `WadeMoney/Stores/SettingsStore.swift`
- Create: `WadeMoney/Formatting/CSVExporter.swift`
- Test: `WadeMoneyTests/SettingsWriteTests.swift`
- Test: `WadeMoneyTests/CSVExporterTests.swift`

**Interfaces:**
- Produces:
  - `SettingsStore`에 `func setMonthStartDay(_ day: Int) throws`(1...28 클램프), `func setAIEnabled(_ enabled: Bool) throws`
  - `enum CSVExporter { static func csv(_ records: [TransactionRecord], categories: [CategoryRef], calendar: Calendar) -> String }` — 헤더 `날짜,종류,카테고리,금액,메모` + 행들

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/SettingsWriteTests.swift`:

```swift
import Foundation
import Testing
@testable import WadeMoney

@MainActor
struct SettingsWriteTests {
    func store() throws -> (SettingsStore, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        return (SettingsStore(context: container.mainContext), container)
    }

    @Test func setMonthStartDayClampsAndPersists() throws {
        let (s, c) = try store()
        try s.setMonthStartDay(25)
        #expect(try s.settings().monthStartDay == 25)
        try s.setMonthStartDay(99)   // 28로 클램프
        #expect(try s.settings().monthStartDay == 28)
        try s.setMonthStartDay(0)    // 1로 클램프
        #expect(try s.settings().monthStartDay == 1)
        _ = c
    }

    @Test func setAIEnabledPersists() throws {
        let (s, c) = try store()
        try s.setAIEnabled(false)
        #expect(try s.settings().aiEnabled == false)
        _ = c
    }
}
```

`WadeMoneyTests/CSVExporterTests.swift`:

```swift
import Foundation
import Testing
import WadeMoneyCore
@testable import WadeMoney

struct CSVExporterTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }

    @Test func csvHasHeaderAndRows() {
        let food = CategoryRef(id: UUID(), name: "식비", iconName: "restaurant", colorHex: "#E28A4E", sortOrder: 0)
        let recs = [
            TransactionRecord(amount: 9000, type: .expense, categoryID: food.id, memo: "점심", date: date(2026, 7, 15)),
            TransactionRecord(amount: 45000, type: .income, categoryID: nil, memo: nil, date: date(2026, 7, 10)),
        ]
        let csv = CSVExporter.csv(recs, categories: [food], calendar: utc)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.first == "날짜,종류,카테고리,금액,메모")
        #expect(lines.contains { $0.contains("2026-07-15") && $0.contains("지출") && $0.contains("식비") && $0.contains("9000") && $0.contains("점심") })
        #expect(lines.contains { $0.contains("2026-07-10") && $0.contains("수입") && $0.contains("45000") })
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ...`
Expected: 컴파일 실패 — `setMonthStartDay`/`CSVExporter` 없음.

- [ ] **Step 3: 설정 세터 구현**

`WadeMoney/Stores/SettingsStore.swift`에 추가:

```swift
    func setMonthStartDay(_ day: Int) throws {
        let model = try settingsModel()
        model.monthStartDay = min(max(day, 1), 28)
        try context.save()
    }

    func setAIEnabled(_ enabled: Bool) throws {
        let model = try settingsModel()
        model.aiEnabled = enabled
        try context.save()
    }
```

- [ ] **Step 4: CSV 내보내기 구현**

`WadeMoney/Formatting/CSVExporter.swift`:

```swift
import Foundation
import WadeMoneyCore

enum CSVExporter {
    static func csv(_ records: [TransactionRecord], categories: [CategoryRef], calendar: Calendar) -> String {
        let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        var lines = ["날짜,종류,카테고리,금액,메모"]
        let df = DateFormatter()
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        for r in records {
            let dateStr = df.string(from: r.date)
            let kind = r.type == .income ? "수입" : "지출"
            let catName = r.categoryID.flatMap { byID[$0] } ?? (r.type == .income ? "" : "기타")
            let amount = "\(NSDecimalNumber(decimal: r.amount).intValue)"
            let memo = escape(r.memo ?? "")
            lines.append("\(dateStr),\(kind),\(escape(catName)),\(amount),\(memo)")
        }
        return lines.joined(separator: "\n")
    }

    /// 콤마·따옴표·개행이 있으면 CSV 규칙대로 큰따옴표로 감싼다.
    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
```

- [ ] **Step 5: 통과 확인 + 커밋**

전체 GREEN(누적 47). 커밋:
```bash
git add WadeMoney/Stores/SettingsStore.swift WadeMoney/Formatting/CSVExporter.swift WadeMoneyTests/SettingsWriteTests.swift WadeMoneyTests/CSVExporterTests.swift
git commit -m "feat(app): add settings setters and CSV export"
```

---

### Task 4: `HistoryViewModel` (날짜 그룹핑 + 필터 + 표시)

**Files:**
- Create: `WadeMoney/Screens/History/HistoryViewModel.swift`
- Test: `WadeMoneyTests/HistoryViewModelTests.swift`

**Interfaces:**
- Consumes: `LedgerRepository`, `WadeMoneyCore`, `Won`, `Icon`
- Produces (`@Observable @MainActor`):
  - `HistoryViewModel(repository:, now:, calendar:)`
  - `var filter: HistoryFilter`, `func load()`, `var chips: [FilterChip]`(전체·카테고리들·수입), `var groups: [DayGroup]`, `var isEmpty: Bool`
  - `struct FilterChip: Identifiable { id; label; filter: HistoryFilter; isSelected: Bool }`
  - `struct DayGroup: Identifiable { id; dateLabel: String; tag: String?; sumText: String; sumIsIncome: Bool; rows: [Row] }`
  - `struct Row: Identifiable { id: UUID; name: String; iconName: String; colorHex: String; categoryName: String; timeText: String; amountText: String; isIncome: Bool }`

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/HistoryViewModelTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct HistoryViewModelTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int, _ hh: Int = 12) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d; comps.hour = hh
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

    @Test func groupsByDayWithTodayTag() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비")
        try r.addTransaction(amount: 9000, type: .expense, categoryID: food, memo: "점심", date: date(2026, 7, 15, 12))
        try r.addTransaction(amount: 3000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 14, 9))
        let vm = HistoryViewModel(repository: r, now: date(2026, 7, 15, 20), calendar: utc)
        vm.load()
        #expect(vm.groups.count == 2)
        #expect(vm.groups[0].tag == "오늘")       // 최신 그룹 = 오늘
        #expect(vm.groups[1].tag == "어제")
        #expect(vm.groups[0].sumText.contains("9,000"))
        #expect(vm.groups[0].rows.first?.isIncome == false)
        _ = c
    }

    @Test func incomeFilterShowsOnlyIncome() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비")
        try r.addTransaction(amount: 9000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 15))
        try r.addTransaction(amount: 45000, type: .income, categoryID: nil, memo: "환급", date: date(2026, 7, 15))
        let vm = HistoryViewModel(repository: r, now: date(2026, 7, 15, 20), calendar: utc)
        vm.filter = .income
        vm.load()
        let allRows = vm.groups.flatMap(\.rows)
        #expect(allRows.count == 1)
        #expect(allRows[0].isIncome == true)
        #expect(allRows[0].amountText.hasPrefix("+"))
        _ = c
    }

    @Test func emptyWhenNoMatches() throws {
        let (r, c) = try repo()
        let vm = HistoryViewModel(repository: r, now: date(2026, 7, 15), calendar: utc)
        vm.filter = .income
        vm.load()
        #expect(vm.isEmpty)
        _ = c
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ...`
Expected: 컴파일 실패 — `cannot find 'HistoryViewModel'`.

- [ ] **Step 3: 구현 작성**

`WadeMoney/Screens/History/HistoryViewModel.swift`:

```swift
import Foundation
import Observation
import WadeMoneyCore

@MainActor
@Observable
final class HistoryViewModel {
    struct FilterChip: Identifiable {
        let id: String
        let label: String
        let filter: HistoryFilter
        let isSelected: Bool
    }
    struct Row: Identifiable {
        let id: UUID
        let name: String
        let iconName: String
        let colorHex: String
        let categoryName: String
        let timeText: String
        let amountText: String
        let isIncome: Bool
    }
    struct DayGroup: Identifiable {
        let id: String
        let dateLabel: String
        let tag: String?
        let sumText: String
        let sumIsIncome: Bool
        let rows: [Row]
    }

    private let repository: LedgerRepository
    private let now: Date
    private let calendar: Calendar

    var filter: HistoryFilter = .all
    private(set) var chips: [FilterChip] = []
    private(set) var groups: [DayGroup] = []

    var isEmpty: Bool { groups.isEmpty }

    init(repository: LedgerRepository, now: Date, calendar: Calendar) {
        self.repository = repository
        self.now = now
        self.calendar = calendar
    }

    func load() {
        let categories = (try? repository.allCategories(includeArchived: true)) ?? []
        let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        chips = buildChips(categories: categories)

        let records = (try? repository.transactions(filter: filter)) ?? []
        groups = groupByDay(records, byID: byID)
    }

    private func buildChips(categories: [CategoryRef]) -> [FilterChip] {
        var result: [FilterChip] = [
            FilterChip(id: "all", label: "전체", filter: .all, isSelected: filter == .all)
        ]
        for cat in categories where !cat.isArchived {
            result.append(FilterChip(id: cat.id.uuidString, label: cat.name,
                                     filter: .category(cat.id), isSelected: filter == .category(cat.id)))
        }
        result.append(FilterChip(id: "income", label: "수입", filter: .income, isSelected: filter == .income))
        return result
    }

    private func groupByDay(_ records: [TransactionRecord], byID: [UUID: CategoryRef]) -> [DayGroup] {
        let grouped = Dictionary(grouping: records) { calendar.startOfDay(for: $0.date) }
        let sortedDays = grouped.keys.sorted(by: >)
        return sortedDays.map { day in
            let items = (grouped[day] ?? []).sorted { $0.date > $1.date }
            var expense = Decimal(0), income = Decimal(0)
            for it in items { if it.type == .income { income += it.amount } else { expense += it.amount } }
            let sumIsIncome = expense == 0 && income > 0
            let sumText = sumIsIncome ? "+\(Won.string(income))" : "−\(Won.string(expense))"
            return DayGroup(
                id: ISO8601DateFormatter().string(from: day),
                dateLabel: dayLabel(day),
                tag: relativeTag(day),
                sumText: sumText,
                sumIsIncome: sumIsIncome,
                rows: items.map { row($0, byID: byID) }
            )
        }
    }

    private func row(_ r: TransactionRecord, byID: [UUID: CategoryRef]) -> Row {
        let cat = r.categoryID.flatMap { byID[$0] }
        let isIncome = r.type == .income
        let sign = isIncome ? "+" : "−"
        return Row(
            id: r.id,
            name: r.memo?.isEmpty == false ? r.memo! : (isIncome ? "수입" : (cat?.name ?? "기타")),
            iconName: isIncome ? "trending_up" : (cat?.iconName ?? "category"),
            colorHex: isIncome ? "#4E9E6A" : (cat?.colorHex ?? "#A69B8C"),
            categoryName: isIncome ? "수입" : (cat?.name ?? "기타"),
            timeText: timeLabel(r.date),
            amountText: "\(sign)\(Won.string(r.amount))",
            isIncome: isIncome
        )
    }

    private func dayLabel(_ day: Date) -> String {
        let c = calendar.dateComponents([.month, .day], from: day)
        return "\(c.month ?? 0)월 \(c.day ?? 0)일"
    }

    private func relativeTag(_ day: Date) -> String? {
        if calendar.isDate(day, inSameDayAs: now) { return "오늘" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)),
           calendar.isDate(day, inSameDayAs: yesterday) { return "어제" }
        return nil
    }

    private func timeLabel(_ date: Date) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}
```

- [ ] **Step 4: 통과 확인 + 커밋**

전체 GREEN(누적 50). 커밋:
```bash
git add WadeMoney/Screens/History/HistoryViewModel.swift WadeMoneyTests/HistoryViewModelTests.swift
git commit -m "feat(ui): add HistoryViewModel (day grouping, filters)"
```

---

### Task 5: 내역 화면 + 거래 편집(빠른 입력 시트 일반화)

**Files:**
- Modify: `WadeMoney/Screens/QuickAdd/QuickAddViewModel.swift` (편집 모드)
- Modify: `WadeMoney/Screens/QuickAdd/QuickAddSheet.swift` (편집 제목·삭제)
- Create: `WadeMoney/Screens/History/HistoryScreen.swift`
- Modify: `WadeMoney/Screens/RootTabView.swift` (내역 탭 → HistoryScreen)
- Test: `WadeMoneyTests/QuickAddEditTests.swift`

**Interfaces:**
- Produces:
  - `QuickAddViewModel(repository:, editing: TransactionRecord? = nil)` — editing이 있으면 금액·종류·카테고리·메모 프리필, `save(date:)`가 `updateTransaction`로 동작. `var isEditing: Bool`. `func delete() throws`(편집 중일 때만).
  - `HistoryScreen` — 필터 칩 + 날짜 그룹 리스트 + 빈 상태. 행 탭 → 편집 시트.

- [ ] **Step 1: 편집 모드 실패 테스트 작성**

`WadeMoneyTests/QuickAddEditTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct QuickAddEditTests {
    func repo() throws -> (LedgerRepository, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        return (LedgerRepository(context: container.mainContext), container)
    }
    func catID(_ r: LedgerRepository, _ n: String) throws -> UUID {
        try r.allCategories(includeArchived: false).first { $0.name == n }!.id
    }
    func date() -> Date { Date(timeIntervalSince1970: 1_000_000) }

    @Test func editingPrefillsAndUpdates() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비"); let cafe = try catID(r, "카페")
        try r.addTransaction(amount: 5000, type: .expense, categoryID: food, memo: "old", date: date())
        let rec = try r.transactions(filter: .all)[0]

        let vm = QuickAddViewModel(repository: r, editing: rec)
        #expect(vm.isEditing)
        #expect(vm.amountDecimal == 5000)
        #expect(vm.selectedCategoryID == food)
        #expect(vm.memo == "old")

        vm.selectedCategoryID = cafe
        vm.amountDigits = "7000"
        try vm.save(date: date())

        let updated = try #require(try r.transactionRecord(id: rec.id))
        #expect(updated.amount == 7000)
        #expect(updated.categoryID == cafe)
        #expect(try r.transactions(filter: .all).count == 1)   // 새로 추가되지 않음
        _ = c
    }

    @Test func deleteRemovesTransaction() throws {
        let (r, c) = try repo()
        let food = try catID(r, "식비")
        try r.addTransaction(amount: 5000, type: .expense, categoryID: food, memo: nil, date: date())
        let rec = try r.transactions(filter: .all)[0]
        let vm = QuickAddViewModel(repository: r, editing: rec)
        try vm.delete()
        #expect(try r.transactions(filter: .all).isEmpty)
        _ = c
    }
}
```

- [ ] **Step 2: RED 확인**

Run: `xcodebuild test ...`
Expected: 실패 — `QuickAddViewModel`에 `editing:` 이니셜라이저/`isEditing`/`delete` 없음.

- [ ] **Step 3: 편집 모드 구현**

`WadeMoney/Screens/QuickAdd/QuickAddViewModel.swift`를 편집 지원으로 확장. 프로퍼티에 추가하고 이니셜라이저를 교체:

```swift
    private let editingID: UUID?
    var isEditing: Bool { editingID != nil }

    init(repository: LedgerRepository, editing: TransactionRecord? = nil) {
        self.repository = repository
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
```

`save(date:)`를 편집 분기로 교체:

```swift
    func save(date: Date) throws {
        guard canSave else { return }
        let catID = type == .income ? nil : selectedCategoryID
        if let editingID {
            try repository.updateTransaction(id: editingID, amount: amountDecimal, type: type,
                                             categoryID: catID, memo: memo.isEmpty ? nil : memo, date: date)
        } else {
            try repository.addTransaction(amount: amountDecimal, type: type,
                                          categoryID: catID, memo: memo.isEmpty ? nil : memo, date: date)
        }
    }

    func delete() throws {
        guard let editingID else { return }
        try repository.deleteTransaction(id: editingID)
    }
```

> 주의: 기존 `init(repository:)` 호출부(빠른 입력 추가)는 `editing` 기본값 `nil`로 그대로 컴파일된다. `categories`/`type`/`selectedCategoryID`/`memo`/`amountDigits` 프로퍼티 선언에서 기존 초기값은 유지하되, 이니셜라이저에서 편집 시 덮어쓴다(위 코드). `type`의 `didSet`이 init 중에는 호출되지 않으므로 수입 편집 시 `selectedCategoryID`가 nil로 잘 들어간다(수입은 categoryID가 원래 nil).

- [ ] **Step 4: 편집 테스트 통과 확인**

Run: `xcodebuild test ...`
Expected: `QuickAddEditTests` 2 tests PASS.

- [ ] **Step 5: 시트에 편집 제목/삭제 반영**

`QuickAddSheet`에 `var editing: TransactionRecord? = nil`을 추가하고, VM 생성 시 `QuickAddViewModel(repository:, editing: editing)`로 전달. 제목을 `vm.isEditing ? (수입/지출 "수정") : (새 수입/새 지출)`으로. 편집일 때 헤더에 삭제 버튼(휴지통 아이콘)을 두고 `try? vm.delete(); onSaved(); dismiss()`.

```swift
struct QuickAddSheet: View {
    // 기존 프로퍼티에 추가:
    var editing: TransactionRecord? = nil
    // onAppear에서:
    //   if vm == nil { vm = QuickAddViewModel(repository: LedgerRepository(context: modelContext), editing: editing) }
    // 제목: vm.isEditing ? (vm.type == .income ? "수입 수정" : "지출 수정") : (vm.type == .income ? "새 수입" : "새 지출")
    // 편집이면 헤더 우측에 삭제 버튼:
    //   Button { try? vm.delete(); onSaved(); dismiss() } label: { Icon("delete", size: 20).foregroundStyle(WadeColors.bad(scheme)) }
}
```

(전체 시트 구조는 계획 3의 것을 유지하고 위 세 지점만 편집 대응으로 바꾼다.)

- [ ] **Step 6: 내역 화면 작성**

`WadeMoney/Screens/History/HistoryScreen.swift`:

```swift
import SwiftUI
import SwiftData
import WadeMoneyCore

struct HistoryScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HistoryViewModel?
    @State private var editingRecord: TransactionRecord?
    let refreshToken: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("내역").font(WadeFont.pretendard(30, weight: .heavy))
                    .foregroundStyle(WadeColors.ink(scheme))
                    .padding(.bottom, 16)

                if let vm = viewModel {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(vm.chips) { chip in
                                Button {
                                    vm.filter = chip.filter; vm.load()
                                } label: {
                                    Text(chip.label).font(WadeFont.pretendard(13, weight: .bold))
                                        .foregroundStyle(chip.isSelected ? .white : WadeColors.ink2(scheme))
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(chip.isSelected ? WadeColors.primary(scheme) : WadeColors.card(scheme), in: Capsule())
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.bottom, 16)

                    if vm.isEmpty {
                        emptyState
                    } else {
                        ForEach(vm.groups) { group in
                            groupView(group)
                        }
                    }
                }
            }
            .padding(.horizontal, WadeSpacing.screenH)
            .padding(.top, WadeSpacing.contentTop)
            .padding(.bottom, WadeSpacing.contentBottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WadeColors.bg(scheme))
        .sheet(item: $editingRecord) { rec in
            QuickAddSheet(onSaved: { viewModel?.load() }, editing: rec)
        }
        .onChange(of: refreshToken) { viewModel?.load() }
        .onAppear {
            if viewModel == nil {
                let vm = HistoryViewModel(repository: LedgerRepository(context: modelContext), now: Date(), calendar: .current)
                vm.load(); viewModel = vm
            }
        }
    }

    private func groupView(_ group: HistoryViewModel.DayGroup) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(group.dateLabel).font(WadeFont.pretendard(13.5, weight: .heavy))
                if let tag = group.tag {
                    Text(tag).font(WadeFont.pretendard(10.5, weight: .bold))
                        .foregroundStyle(WadeColors.primary(scheme))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(WadeColors.primarysoft(scheme), in: Capsule())
                }
                Spacer()
                Text(group.sumText).font(WadeFont.pretendard(12.5, weight: .bold))
                    .foregroundStyle(group.sumIsIncome ? WadeColors.good(scheme) : WadeColors.ink2(scheme))
            }
            .padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(group.rows) { row in
                    Button { editingRecord = try? recordFor(row.id) } label: { rowView(row) }
                        .buttonStyle(.plain)
                    if row.id != group.rows.last?.id {
                        Divider().overlay(WadeColors.line(scheme)).padding(.leading, 16)
                    }
                }
            }
            .background(WadeColors.card(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.listCard, style: .continuous))
        }
        .padding(.bottom, 20)
    }

    private func rowView(_ row: HistoryViewModel.Row) -> some View {
        HStack(spacing: 13) {
            Icon(row.iconName, size: 21).foregroundStyle(Color(hex: row.colorHex))
                .frame(width: 38, height: 38)
                .background(Color(hex: row.colorHex).opacity(0.13), in: RoundedRectangle(cornerRadius: WadeRadius.iconTile))
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name).font(WadeFont.pretendard(14.5, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme)).lineLimit(1)
                Text("\(row.categoryName) · \(row.timeText)").font(WadeFont.pretendard(11.5)).foregroundStyle(WadeColors.ink3(scheme))
            }
            Spacer()
            Text(row.amountText).font(WadeFont.pretendard(15, weight: .heavy))
                .foregroundStyle(row.isIncome ? WadeColors.good(scheme) : WadeColors.ink(scheme))
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }

    private var emptyState: some View {
        VStack(spacing: 11) {
            Icon("receipt_long", size: 38, filled: false).foregroundStyle(WadeColors.ink3(scheme))
                .frame(width: 74, height: 74)
                .background(WadeColors.card2(scheme), in: Circle())
            Text("아직 기록이 없어요").font(WadeFont.pretendard(16, weight: .heavy)).foregroundStyle(WadeColors.ink2(scheme))
            Text("+ 버튼으로 첫 지출을 기록해보세요").font(WadeFont.pretendard(13)).foregroundStyle(WadeColors.ink3(scheme))
        }
        .frame(maxWidth: .infinity).padding(.top, 64)
    }

    private func recordFor(_ id: UUID) throws -> TransactionRecord? {
        try LedgerRepository(context: modelContext).transactionRecord(id: id)
    }
}
```

`RootTabView`의 `case 1: PlaceholderScreen(title: "내역")`을 `case 1: HistoryScreen(refreshToken: dashboardRefreshToken)`으로 교체하고, 저장 시 내역도 갱신되도록 기존 `dashboardRefreshToken`을 공유(이미 `onSaved`에서 증가). `TransactionRecord`가 `Identifiable`인지 확인 — 이미 `WadeMoneyCore`에서 `Identifiable`(id: UUID) 이므로 `.sheet(item:)`에 사용 가능.

- [ ] **Step 7: 빌드 + 스크린샷 확인**

빌드 후 시뮬레이터 실행, 내역 탭으로 이동한 스크린샷을 캡처(탭 구동이 어려우면 `RootTabView`의 초기 `selection`을 임시로 1로 두고 캡처 후 되돌린다). 확인: 필터 칩(전체/카테고리/수입), 날짜 그룹 헤더(오늘/어제 태그 + 합계), 행(아이콘 타일·이름·카테고리·시간·금액), 빈 상태. 디자인 §5.2와 대조.

- [ ] **Step 8: 전체 스위트 통과 + 커밋**

Run: `xcodebuild test ...` — 전체 GREEN(누적 52).
```bash
git add WadeMoney/Screens/History WadeMoney/Screens/QuickAdd WadeMoney/Screens/RootTabView.swift WadeMoneyTests/QuickAddEditTests.swift
git commit -m "feat(ui): add history screen with transaction edit/delete"
```

---

### Task 6: `SettingsViewModel` + 설정 화면 + 예산 시트 (`AmountKeypad` 추출)

**Files:**
- Create: `WadeMoney/DesignSystem/AmountKeypad.swift` (빠른 입력·예산 시트가 공유하는 키패드)
- Modify: `WadeMoney/Screens/QuickAdd/QuickAddSheet.swift` (추출한 `AmountKeypad` 사용)
- Create: `WadeMoney/Screens/Settings/SettingsViewModel.swift`
- Create: `WadeMoney/Screens/Settings/SettingsScreen.swift`
- Create: `WadeMoney/Screens/Settings/BudgetSheet.swift`
- Modify: `WadeMoney/Screens/RootTabView.swift` (설정 탭 → SettingsScreen)
- Test: `WadeMoneyTests/SettingsViewModelTests.swift`

**Interfaces:**
- Produces:
  - `struct AmountKeypad: View { let onKey: (String) -> Void; let onBackspace: () -> Void }` — 3열 1-9/00/0/⌫
  - `@Observable @MainActor final class SettingsViewModel(settingsStore:, categoryStore:, now:, calendar:)` — `var budgetText: String`, `var monthStartDayText: String`, `var aiEnabled: Bool`, `var categoryCountText: String`; `func load()`, `func setBudget(_ amount: Decimal)`, `func toggleAI()`
  - `SettingsScreen`, `BudgetSheet`

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/SettingsViewModelTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct SettingsViewModelTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }
    func vm() throws -> (SettingsViewModel, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        let ctx = container.mainContext
        let vm = SettingsViewModel(settingsStore: SettingsStore(context: ctx),
                                   categoryStore: CategoryStore(context: ctx),
                                   now: date(2026, 7, 15), calendar: utc)
        return (vm, container)
    }

    @Test func loadsBudgetAndCategoryCount() throws {
        let (vm, c) = try vm()
        vm.setBudget(1_300_000)
        vm.load()
        #expect(vm.budgetText == "1,300,000")
        #expect(vm.categoryCountText == "8개")
        _ = c
    }

    @Test func toggleAIPersists() throws {
        let (vm, c) = try vm()
        vm.load()
        let initial = vm.aiEnabled
        vm.toggleAI()
        #expect(vm.aiEnabled == !initial)
        // reload reflects persisted value
        vm.load()
        #expect(vm.aiEnabled == !initial)
        _ = c
    }
}
```

- [ ] **Step 2: RED 확인**

Run: `xcodebuild test ...`
Expected: 컴파일 실패 — `SettingsViewModel` 없음.

- [ ] **Step 3: 뷰모델 구현**

`WadeMoney/Screens/Settings/SettingsViewModel.swift`:

```swift
import Foundation
import Observation
import WadeMoneyCore

@MainActor
@Observable
final class SettingsViewModel {
    private let settingsStore: SettingsStore
    private let categoryStore: CategoryStore
    private let now: Date
    private let calendar: Calendar

    private(set) var budgetText: String = "0"
    private(set) var monthStartDayText: String = "매월 1일"
    private(set) var aiEnabled: Bool = true
    private(set) var categoryCountText: String = "0개"

    init(settingsStore: SettingsStore, categoryStore: CategoryStore, now: Date, calendar: Calendar) {
        self.settingsStore = settingsStore
        self.categoryStore = categoryStore
        self.now = now
        self.calendar = calendar
    }

    private var currentYearMonth: YearMonth {
        YearMonth(year: calendar.component(.year, from: now), month: calendar.component(.month, from: now))
    }

    func load() {
        let settings = (try? settingsStore.settings()) ?? EngineSettings()
        aiEnabled = settings.aiEnabled
        monthStartDayText = "매월 \(settings.monthStartDay)일"
        let book = try? settingsStore.budgetBook()
        let amount = book?.amount(for: currentYearMonth) ?? 0
        budgetText = Won.string(amount)
        let count = (try? categoryStore.active().count) ?? 0
        categoryCountText = "\(count)개"
    }

    func setBudget(_ amount: Decimal) {
        try? settingsStore.setMonthlyBudget(amount, for: currentYearMonth)
        load()
    }

    func toggleAI() {
        try? settingsStore.setAIEnabled(!aiEnabled)
        load()
    }
}
```

- [ ] **Step 4: 뷰모델 테스트 통과 확인**

Run: `xcodebuild test ...`
Expected: `SettingsViewModelTests` 2 tests PASS.

- [ ] **Step 5: `AmountKeypad` 추출 + 빠른 입력 시트 갱신**

`WadeMoney/DesignSystem/AmountKeypad.swift`:

```swift
import SwiftUI

struct AmountKeypad: View {
    @Environment(\.colorScheme) private var scheme
    let onKey: (String) -> Void
    let onBackspace: () -> Void
    private let keys = ["1","2","3","4","5","6","7","8","9","00","0","←"]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 9) {
            ForEach(keys, id: \.self) { key in
                Button {
                    if key == "←" { onBackspace() } else { onKey(key) }
                } label: {
                    Group {
                        if key == "←" { Icon("backspace", size: 26).foregroundStyle(WadeColors.ink2(scheme)) }
                        else { Text(key).font(WadeFont.pretendard(24, weight: .bold)).foregroundStyle(WadeColors.ink(scheme)) }
                    }
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(WadeColors.card2(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.control))
                }.buttonStyle(.plain)
            }
        }
    }
}
```

`QuickAddSheet`의 인라인 키패드(계획 3의 `keypad(_:)`)를 `AmountKeypad(onKey: { vm.tapKey($0) }, onBackspace: { vm.backspace() })`로 교체.

- [ ] **Step 6: 예산 시트 + 설정 화면 작성**

`WadeMoney/Screens/Settings/BudgetSheet.swift`:

```swift
import SwiftUI
import WadeMoneyCore

struct BudgetSheet: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var digits: String
    let onSave: (Decimal) -> Void

    init(current: Decimal, onSave: @escaping (Decimal) -> Void) {
        self._digits = State(initialValue: current > 0 ? "\(NSDecimalNumber(decimal: current).intValue)" : "")
        self.onSave = onSave
    }

    private var amount: Decimal { Decimal(string: digits) ?? 0 }

    var body: some View {
        VStack(spacing: 14) {
            Text("이번 달 예산").font(WadeFont.pretendard(20, weight: .heavy)).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 16)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("₩").font(WadeFont.pretendard(26, weight: .bold))
                Text(digits.isEmpty ? "0" : Won.string(amount)).font(WadeFont.pretendard(52, weight: .heavy))
            }
            .foregroundStyle(amount > 0 ? WadeColors.primary(scheme) : WadeColors.ink3(scheme))
            AmountKeypad(onKey: { key in
                if digits.isEmpty && key.allSatisfy({ $0 == "0" }) { return }
                if digits.count + key.count <= 12 { digits += key }
            }, onBackspace: { if !digits.isEmpty { digits.removeLast() } })
            Button {
                onSave(amount); dismiss()
            } label: {
                Text("예산 저장").font(WadeFont.pretendard(17, weight: .heavy))
                    .foregroundStyle(amount > 0 ? .white : WadeColors.ink3(scheme))
                    .frame(maxWidth: .infinity).padding(17)
                    .background(amount > 0 ? WadeColors.primary(scheme) : WadeColors.track(scheme),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }.buttonStyle(.plain).disabled(amount <= 0)
        }
        .padding(.horizontal, 20).padding(.bottom, 30)
        .presentationDetents([.medium, .large])
        .background(WadeColors.sheet(scheme))
    }
}
```

`WadeMoney/Screens/Settings/SettingsScreen.swift`:

```swift
import SwiftUI
import SwiftData
import WadeMoneyCore

struct SettingsScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?
    @State private var showBudget = false
    @State private var showCategories = false
    @State private var budgetValue: Decimal = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("설정").font(WadeFont.pretendard(30, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                    if let vm = viewModel {
                        section("예산") {
                            row(icon: "account_balance_wallet", tint: WadeColors.primary(scheme), label: "이번 달 예산",
                                trailing: "₩\(vm.budgetText)") { showBudget = true }
                            row(icon: "event", tint: WadeColors.ink2(scheme), label: "월 시작일", trailing: vm.monthStartDayText, action: nil)
                        }
                        section("카테고리 · AI") {
                            row(icon: "category", tint: WadeColors.ink2(scheme), label: "카테고리 관리",
                                trailing: vm.categoryCountText) { showCategories = true }
                            aiToggleRow(vm)
                        }
                        section("동기화 · 데이터") {
                            row(icon: "cloud_done", tint: WadeColors.good(scheme), label: "iCloud 동기화", trailing: nil, action: nil)
                            row(icon: "ios_share", tint: WadeColors.ink2(scheme), label: "CSV 내보내기", trailing: nil) { exportCSV() }
                        }
                        Text("WadeMoney v1.0 · 데이터는 이 기기에 있어요")
                            .font(WadeFont.pretendard(11.5)).foregroundStyle(WadeColors.ink3(scheme))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, WadeSpacing.screenH)
                .padding(.top, WadeSpacing.contentTop).padding(.bottom, WadeSpacing.contentBottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WadeColors.bg(scheme))
            .navigationDestination(isPresented: $showCategories) { CategoryManageScreen() }
        }
        .sheet(isPresented: $showBudget) {
            BudgetSheet(current: budgetValue) { amount in viewModel?.setBudget(amount); viewModel?.load(); reloadBudgetValue() }
        }
        .onAppear {
            if viewModel == nil {
                let ctx = modelContext
                let vm = SettingsViewModel(settingsStore: SettingsStore(context: ctx),
                                           categoryStore: CategoryStore(context: ctx),
                                           now: Date(), calendar: .current)
                vm.load(); viewModel = vm; reloadBudgetValue()
            }
        }
    }

    private func reloadBudgetValue() {
        let ctx = modelContext
        let cal = Calendar.current
        let ym = YearMonth(year: cal.component(.year, from: Date()), month: cal.component(.month, from: Date()))
        budgetValue = (try? SettingsStore(context: ctx).budgetBook().amount(for: ym)) ?? 0
    }

    private func exportCSV() {
        let ctx = modelContext
        let repo = LedgerRepository(context: ctx)
        let records = (try? repo.transactions(filter: .all)) ?? []
        let cats = (try? repo.allCategories(includeArchived: true)) ?? []
        let csv = CSVExporter.csv(records, categories: cats, calendar: .current)
        // 데모: 파일로 쓰고 공유 시트는 후속. 여기선 콘솔·임시파일까지만.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("wademoney.csv")
        try? csv.data(using: .utf8)?.write(to: url)
    }

    @ViewBuilder private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(WadeFont.pretendard(12.5, weight: .bold)).foregroundStyle(WadeColors.ink3(scheme)).padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(WadeColors.card(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.listCard, style: .continuous))
        }
    }

    private func row(icon: String, tint: Color, label: String, trailing: String?, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            HStack(spacing: 13) {
                Icon(icon, size: 20).foregroundStyle(tint).frame(width: 36, height: 36)
                    .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                Text(label).font(WadeFont.pretendard(15, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
                Spacer()
                if let trailing { Text(trailing).font(WadeFont.pretendard(15, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme)) }
                if action != nil { Icon("chevron_right", size: 20, filled: false).foregroundStyle(WadeColors.ink3(scheme)) }
            }
            .padding(.horizontal, 16).padding(.vertical, 15)
        }.buttonStyle(.plain).disabled(action == nil)
    }

    private func aiToggleRow(_ vm: SettingsViewModel) -> some View {
        HStack(spacing: 13) {
            Icon("auto_awesome", size: 20).foregroundStyle(WadeColors.primary(scheme)).frame(width: 36, height: 36)
                .background(WadeColors.aitint2(scheme), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text("AI 기능").font(WadeFont.pretendard(15, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
                Text("온디바이스 · Apple Intelligence").font(WadeFont.pretendard(11.5)).foregroundStyle(WadeColors.ink3(scheme))
            }
            Spacer()
            Toggle("", isOn: Binding(get: { vm.aiEnabled }, set: { _ in vm.toggleAI() })).labelsHidden().tint(WadeColors.primary(scheme))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}
```

`RootTabView`의 `case 4: PlaceholderScreen(title: "설정")`을 `case 4: SettingsScreen()`으로 교체.

> `CategoryManageScreen`은 Task 8에서 만든다. Task 6 실행 시 미완성이면 임시 스텁(`struct CategoryManageScreen: View { var body: some View { Text("카테고리 관리") } }`)을 두고 Task 8에서 완성한다.

- [ ] **Step 7: 빌드 + 스크린샷 확인**

설정 탭 스크린샷(필요 시 초기 selection 임시 변경). 확인: 섹션(예산/카테고리·AI/동기화·데이터), 행(아이콘 타일·라벨·값·chevron), AI 토글, 푸터. 예산 행 탭 → 예산 시트(키패드). 디자인 §5.3과 대조.

- [ ] **Step 8: 전체 스위트 통과 + 커밋**

Run: `xcodebuild test ...` — 전체 GREEN(누적 54).
```bash
git add WadeMoney/DesignSystem/AmountKeypad.swift WadeMoney/Screens/QuickAdd WadeMoney/Screens/Settings WadeMoney/Screens/RootTabView.swift WadeMoneyTests/SettingsViewModelTests.swift
git commit -m "feat(ui): add settings screen, budget sheet, shared AmountKeypad"
```

---

### Task 7: `CategoryManageViewModel`

**Files:**
- Create: `WadeMoney/Screens/Categories/CategoryManageViewModel.swift`
- Test: `WadeMoneyTests/CategoryManageViewModelTests.swift`

**Interfaces:**
- Consumes: `CategoryStore`, `LedgerRepository`(사용액 집계), `WadeMoneyCore`, `Won`
- Produces (`@Observable @MainActor`):
  - `CategoryManageViewModel(categoryStore:, repository:, now:, calendar:)`
  - `var activeItems: [Item]`, `var archivedItems: [Item]`, `func load()`
  - `func add(name:iconName:colorHex:)`, `func update(id:name:iconName:colorHex:)`, `func archive(id:)`, `func restore(id:)`, `func move(from:to:)`
  - `struct Item: Identifiable { id: UUID; name; iconName; colorHex; usageText: String }` — usageText = 이번 달 사용액("이번 달 12,000원"/"이번 달 사용 없음")

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/CategoryManageViewModelTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct CategoryManageViewModelTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }
    func vm() throws -> (CategoryManageViewModel, LedgerRepository, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        let ctx = container.mainContext
        let repo = LedgerRepository(context: ctx)
        let vm = CategoryManageViewModel(categoryStore: CategoryStore(context: ctx), repository: repo,
                                         now: date(2026, 7, 15), calendar: utc)
        return (vm, repo, container)
    }

    @Test func loadsActiveWithUsage() throws {
        let (vm, repo, c) = try vm()
        let food = try repo.allCategories(includeArchived: false).first { $0.name == "식비" }!.id
        try repo.addTransaction(amount: 12000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 10))
        vm.load()
        #expect(vm.activeItems.count == 8)
        let foodItem = try #require(vm.activeItems.first { $0.name == "식비" })
        #expect(foodItem.usageText.contains("12,000"))
        let cafeItem = try #require(vm.activeItems.first { $0.name == "카페" })
        #expect(cafeItem.usageText == "이번 달 사용 없음")
        _ = c
    }

    @Test func addArchiveRestoreFlow() throws {
        let (vm, _, c) = try vm()
        vm.load()
        vm.add(name: "여행", iconName: "flight", colorHex: "#4DA0C4")
        #expect(vm.activeItems.contains { $0.name == "여행" })
        let travel = vm.activeItems.first { $0.name == "여행" }!.id
        vm.archive(id: travel)
        #expect(vm.activeItems.contains { $0.id == travel } == false)
        #expect(vm.archivedItems.contains { $0.id == travel })
        vm.restore(id: travel)
        #expect(vm.activeItems.contains { $0.id == travel })
        _ = c
    }
}
```

- [ ] **Step 2: RED 확인**

Run: `xcodebuild test ...`
Expected: 컴파일 실패 — `CategoryManageViewModel` 없음.

- [ ] **Step 3: 구현 작성**

`WadeMoney/Screens/Categories/CategoryManageViewModel.swift`:

```swift
import Foundation
import Observation
import WadeMoneyCore

@MainActor
@Observable
final class CategoryManageViewModel {
    struct Item: Identifiable {
        let id: UUID
        let name: String
        let iconName: String
        let colorHex: String
        let usageText: String
    }

    private let categoryStore: CategoryStore
    private let repository: LedgerRepository
    private let now: Date
    private let calendar: Calendar

    private(set) var activeItems: [Item] = []
    private(set) var archivedItems: [Item] = []

    init(categoryStore: CategoryStore, repository: LedgerRepository, now: Date, calendar: Calendar) {
        self.categoryStore = categoryStore
        self.repository = repository
        self.now = now
        self.calendar = calendar
    }

    func load() {
        let settings = (try? repository.settingsMonthStartDay()) ?? 1
        let calc = PeriodCalculator(calendar: calendar, monthStartDay: settings)
        let month = calc.period(.month, containing: now)
        let txns = (try? repository.allTransactions()) ?? []
        let totals = Dictionary(grouping: txns.filter { $0.type == .expense && $0.date >= month.start && $0.date < month.end },
                                by: { $0.categoryID })
            .mapValues { $0.reduce(Decimal(0)) { $0 + $1.amount } }

        func item(_ ref: CategoryRef) -> Item {
            let used = totals[ref.id] ?? 0
            let usage = used > 0 ? "이번 달 \(Won.string(used))원" : "이번 달 사용 없음"
            return Item(id: ref.id, name: ref.name, iconName: ref.iconName, colorHex: ref.colorHex, usageText: usage)
        }
        activeItems = ((try? categoryStore.active()) ?? []).map(item)
        archivedItems = ((try? categoryStore.archived()) ?? []).map(item)
    }

    func add(name: String, iconName: String, colorHex: String) {
        try? categoryStore.add(name: name, iconName: iconName, colorHex: colorHex); load()
    }
    func update(id: UUID, name: String, iconName: String, colorHex: String) {
        try? categoryStore.update(id: id, name: name, iconName: iconName, colorHex: colorHex); load()
    }
    func archive(id: UUID) { try? categoryStore.archive(id: id); load() }
    func restore(id: UUID) { try? categoryStore.restore(id: id); load() }

    func move(from source: IndexSet, to destination: Int) {
        var ids = activeItems.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        try? categoryStore.reorder(ids); load()
    }
}
```

- [ ] **Step 4: 통과 확인 + 커밋**

전체 GREEN(누적 56). 커밋:
```bash
git add WadeMoney/Screens/Categories/CategoryManageViewModel.swift WadeMoneyTests/CategoryManageViewModelTests.swift
git commit -m "feat(ui): add CategoryManageViewModel"
```

---

### Task 8: 카테고리 관리 화면 + 편집 시트(아이콘·색 선택)

**Files:**
- Create: `WadeMoney/Screens/Categories/CategoryManageScreen.swift` (Task 6 스텁 교체)
- Create: `WadeMoney/Screens/Categories/CategoryEditSheet.swift`
- Test: (뷰는 스크린샷 검증; 로직은 Task 7에서 커버됨 — 새 단위 테스트 없음)

**Interfaces:**
- Consumes: `CategoryManageViewModel`, 디자인 토큰
- Produces:
  - `CategoryManageScreen` — 사용 중(드래그 재정렬·탭하면 편집) + 보관됨(복원) + 새 카테고리 버튼
  - `CategoryEditSheet(editing: CategoryManageViewModel.Item?, onSave: (name,icon,color) -> Void, onArchive: (() -> Void)?)` — 이름 필드 + 아이콘 그리드 + 색 팔레트
  - `enum CategoryPalette { static let icons: [String]; static let colors: [String] }` — 큐레이션된 Material Symbol 이름·색

- [ ] **Step 1: 팔레트 + 편집 시트 작성**

`WadeMoney/Screens/Categories/CategoryEditSheet.swift`:

```swift
import SwiftUI

enum CategoryPalette {
    static let icons = ["restaurant","local_cafe","directions_bus","shopping_bag","movie","medical_services",
                        "home","category","flight","pets","fitness_center","school","card_giftcard","sports_esports",
                        "checkroom","local_gas_station","phone_iphone","savings"]
    static let colors = ["#E28A4E","#C4924E","#6F9FD8","#DB84AE","#D8AE45","#5DB794","#8E82CE","#A69B8C",
                         "#4DA0C4","#E0687A","#7BB661","#B072C4"]
}

struct CategoryEditSheet: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var icon: String
    @State private var color: String
    let isEditing: Bool
    let onSave: (String, String, String) -> Void
    let onArchive: (() -> Void)?

    init(editing item: CategoryManageViewModel.Item?, onSave: @escaping (String, String, String) -> Void, onArchive: (() -> Void)?) {
        _name = State(initialValue: item?.name ?? "")
        _icon = State(initialValue: item?.iconName ?? CategoryPalette.icons[0])
        _color = State(initialValue: item?.colorHex ?? CategoryPalette.colors[0])
        isEditing = item != nil
        self.onSave = onSave
        self.onArchive = onArchive
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(isEditing ? "카테고리 수정" : "새 카테고리").font(WadeFont.pretendard(20, weight: .heavy)).padding(.top, 16)
                // 미리보기 + 이름
                HStack(spacing: 12) {
                    Icon(icon, size: 24).foregroundStyle(Color(hex: color)).frame(width: 46, height: 46)
                        .background(Color(hex: color).opacity(0.15), in: RoundedRectangle(cornerRadius: WadeRadius.control))
                    TextField("이름", text: $name).font(WadeFont.pretendard(17, weight: .semibold))
                }
                sectionLabel("아이콘")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(CategoryPalette.icons, id: \.self) { name in
                        Button { icon = name } label: {
                            Icon(name, size: 20).foregroundStyle(icon == name ? Color(hex: color) : WadeColors.ink2(scheme))
                                .frame(width: 42, height: 42)
                                .background(icon == name ? Color(hex: color).opacity(0.15) : WadeColors.card2(scheme),
                                            in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                    }
                }
                sectionLabel("색")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(CategoryPalette.colors, id: \.self) { hex in
                        Button { color = hex } label: {
                            Circle().fill(Color(hex: hex)).frame(width: 36, height: 36)
                                .overlay(Circle().stroke(WadeColors.ink(scheme), lineWidth: color == hex ? 2 : 0))
                        }.buttonStyle(.plain)
                    }
                }
                Button {
                    onSave(name.trimmingCharacters(in: .whitespaces), icon, color); dismiss()
                } label: {
                    Text("저장").font(WadeFont.pretendard(17, weight: .heavy))
                        .foregroundStyle(canSave ? .white : WadeColors.ink3(scheme))
                        .frame(maxWidth: .infinity).padding(16)
                        .background(canSave ? WadeColors.primary(scheme) : WadeColors.track(scheme),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }.buttonStyle(.plain).disabled(!canSave)
                if let onArchive {
                    Button { onArchive(); dismiss() } label: {
                        Text("보관하기").font(WadeFont.pretendard(15, weight: .bold)).foregroundStyle(WadeColors.bad(scheme))
                            .frame(maxWidth: .infinity).padding(12)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 30)
        }
        .presentationDetents([.large])
        .background(WadeColors.sheet(scheme))
    }

    private func sectionLabel(_ t: String) -> some View {
        Text(t).font(WadeFont.pretendard(12.5, weight: .bold)).foregroundStyle(WadeColors.ink3(scheme))
    }
}
```

- [ ] **Step 2: 관리 화면 작성**

`WadeMoney/Screens/Categories/CategoryManageScreen.swift`:

```swift
import SwiftUI
import SwiftData

struct CategoryManageScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: CategoryManageViewModel?
    @State private var editingItem: CategoryManageViewModel.Item?
    @State private var showNew = false

    var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    Section("사용 중") {
                        ForEach(vm.activeItems) { item in
                            Button { editingItem = item } label: { rowContent(item) }.buttonStyle(.plain)
                        }
                        .onMove { vm.move(from: $0, to: $1) }
                    }
                    if !vm.archivedItems.isEmpty {
                        Section("보관됨") {
                            ForEach(vm.archivedItems) { item in
                                HStack {
                                    rowContent(item).opacity(0.6)
                                    Spacer()
                                    Button("복원") { vm.restore(id: item.id) }
                                        .font(WadeFont.pretendard(12, weight: .bold)).foregroundStyle(WadeColors.ink2(scheme))
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .environment(\.editMode, .constant(.active))
            }
        }
        .navigationTitle("카테고리 관리")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showNew = true } label: { Icon("add", size: 22) } } }
        .sheet(item: $editingItem) { item in
            CategoryEditSheet(editing: item,
                              onSave: { n, i, c in viewModel?.update(id: item.id, name: n, iconName: i, colorHex: c) },
                              onArchive: { viewModel?.archive(id: item.id) })
        }
        .sheet(isPresented: $showNew) {
            CategoryEditSheet(editing: nil,
                              onSave: { n, i, c in viewModel?.add(name: n, iconName: i, colorHex: c) },
                              onArchive: nil)
        }
        .onAppear {
            if viewModel == nil {
                let ctx = modelContext
                let vm = CategoryManageViewModel(categoryStore: CategoryStore(context: ctx),
                                                 repository: LedgerRepository(context: ctx),
                                                 now: Date(), calendar: .current)
                vm.load(); viewModel = vm
            }
        }
    }

    private func rowContent(_ item: CategoryManageViewModel.Item) -> some View {
        HStack(spacing: 13) {
            Icon(item.iconName, size: 20).foregroundStyle(Color(hex: item.colorHex)).frame(width: 36, height: 36)
                .background(Color(hex: item.colorHex).opacity(0.15), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(WadeFont.pretendard(15, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
                Text(item.usageText).font(WadeFont.pretendard(11.5)).foregroundStyle(WadeColors.ink3(scheme))
            }
        }
    }
}
```

- [ ] **Step 3: 빌드 + 스크린샷 확인**

설정 → 카테고리 관리 진입 스크린샷(필요 시 앱 진입점을 임시로 이 화면으로 두고 캡처 후 되돌린다). 확인: 사용 중 리스트(드래그 핸들·아이콘·이름·사용액), 보관됨 섹션(복원), 우상단 새 카테고리(+), 편집 시트(아이콘 그리드·색 팔레트). 디자인 §5.4와 대조.

- [ ] **Step 4: 전체 스위트 통과 + 커밋**

Run: `xcodebuild test ...` — 전체 GREEN(누적 56, 뷰 태스크라 테스트 수 불변).
```bash
git add WadeMoney/Screens/Categories/CategoryManageScreen.swift WadeMoney/Screens/Categories/CategoryEditSheet.swift
git commit -m "feat(ui): add category management screen and edit sheet"
```

---

## Self-Review (계획 작성자 확인 완료)

- **스펙 커버리지**: 내역(§5.2: 필터 칩·날짜 그룹·수정/삭제·빈 상태)→Task 4·5; 설정(§5.3: 예산·월 시작일·카테고리 관리 링크·AI 토글·동기화 상태·CSV)→Task 3·6; 카테고리 관리(§5.4: 사용 중·보관됨·복원·새 카테고리·아이콘/색)→Task 7·8. 리뷰 백로그: 거래 편집(`updateTransaction`)→Task 1·5, `totalIncome` 노출→Task 1, `AmountKeypad` 중복 제거→Task 6. **AI 리포트·인사이트·메모 다듬기는 계획 5, 위젯은 계획 6.**
- **뷰모델 순수성**: 모든 뷰모델이 `now`/`calendar` 주입. `Date()`/`.current`는 화면 `onAppear` 진입점에서만.
- **실행 순서 의존성(명시)**: Task 5의 `HistoryScreen`은 편집을 위해 Task 5에서 확장한 `QuickAddSheet(editing:)`를 쓴다(같은 태스크 내). Task 6의 `SettingsScreen`은 Task 8의 `CategoryManageScreen`을 참조 → Task 6에서 임시 스텁, Task 8에서 완성(Task 6 Step 6 주석에 기재).
- **타입 일관성**: `HistoryFilter`(Task 1)가 Task 4·5에서 재사용. `QuickAddViewModel.init(repository:editing:)`·`save(date:)`·`delete()`가 Task 5 시트/테스트와 일치. `SettingsStore.setMonthlyBudget/budgetBook/settings/setAIEnabled/setMonthStartDay`, `CategoryStore.active/archived/add/update/archive/restore/reorder`, `LedgerRepository.settingsMonthStartDay/allTransactions/transactions/transactionRecord/updateTransaction`가 소비처와 일치.
- **플레이스홀더 스캔**: CSV 내보내기는 임시파일 저장까지만(공유 시트는 후속) — 명시함. 그 외 미완성 없음.

## 수동 검증 단계 (자동 스위트 밖)

뷰 태스크(5·6·8)는 시뮬레이터 스크린샷으로 디자인 대조. 탭 구동이 어려우면 진입점/초기 selection을 임시 변경해 캡처 후 되돌린다(계획 3에서 쓴 방식). 라이트/다크 둘 다 확인 권장.

## 다음 계획으로의 인터페이스

- 계획 5(AI): 설정의 AI 토글(`aiEnabled`)을 읽어 대시보드 AI 인사이트 카드·빠른 입력 "AI 다듬기"·AI 리포트 화면을 Foundation Models로 구현. `DashboardSummary`(totalIncome 포함)와 카테고리별 전월 대비 변화는 리포트 입력으로 사용.
- 계획 6(위젯): App Group 공유 저장소로 홈/잠금화면/대화형 기록 위젯 + App Intents.
- 남은 폴리시(계획 3 리뷰): onPrimary/white 토큰, 잔여 cornerRadius 리터럴, tabbar/line 보더, Material Symbols 폰트 서브셋 — 여력 시 반영.
