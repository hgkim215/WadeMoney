# WadeMoneyCore — 도메인 & 계산 엔진 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** WadeMoney 가계부의 모든 계산(기간 경계, 예산 스냅샷 해석, 지출 집계, 페이스 비교, 도넛 그룹핑, 예상 지출)을 UI·영속화와 완전히 분리된 순수 Swift 패키지로 구현하고, `swift test`로 전부 검증한다.

**Architecture:** SwiftData·SwiftUI에 의존하지 않는 순수 값 타입 + 순수 함수/구조체. 앱 계층(계획 2)이 SwiftData `@Model`을 이 값 타입으로 매핑해 엔진을 호출한다. 결정성 확보를 위해 모든 날짜 계산은 주입된 `Calendar`(테스트는 UTC 고정)를 사용한다.

**Tech Stack:** Swift 6.3, Swift Package Manager (library), Foundation, Swift Testing (`import Testing`).

## Global Constraints

- 최소 플랫폼: 패키지는 **macOS 14 / iOS 26**(엔진은 Foundation만 사용 — 커맨드라인 `swift test`가 macOS에서 동작). 앱 계층은 iOS 26.
- **통화 없음**: 금액은 전부 `Decimal`(원 단위). 포매팅(₩·천단위)은 UI 계층 책임 — 엔진은 순수 수치만 반환.
- **집계는 지출만**: 모든 합계·도넛·페이스는 `type == .expense`만 대상. 수입은 제외.
- **기간 경계**: `monthStartDay`(1~28) 기준. 반열림 구간 `[start, end)`. 월 시작일은 28 이하로 클램프(모든 달에 존재 보장).
- **페이스 비교 불가 조건**: 직전 기간 누적이 0(또는 데이터 없음)이면 `deltaRatio = nil`.
- **네이밍**: 패키지·모듈명 `WadeMoneyCore`. `public` API로 노출.
- 날짜 계산은 **절대 `Date()` / `Calendar.current`를 엔진 내부에서 직접 호출하지 않는다**. 항상 파라미터·주입으로 받는다.

---

### Task 1: 패키지 스캐폴드 + `YearMonth` 값 타입

**Files:**
- Create: `WadeMoneyCore/Package.swift`
- Create: `WadeMoneyCore/Sources/WadeMoneyCore/YearMonth.swift`
- Test: `WadeMoneyCore/Tests/WadeMoneyCoreTests/YearMonthTests.swift`

**Interfaces:**
- Consumes: (없음)
- Produces:
  - `struct YearMonth: Equatable, Comparable, Hashable, Sendable { let year: Int; let month: Int; init(year:month:); func adding(months: Int) -> YearMonth }`

- [ ] **Step 1: 패키지 매니페스트 작성**

`WadeMoneyCore/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WadeMoneyCore",
    platforms: [.macOS(.v14), .iOS(.v18)],
    products: [
        .library(name: "WadeMoneyCore", targets: ["WadeMoneyCore"]),
    ],
    targets: [
        .target(name: "WadeMoneyCore"),
        .testTarget(name: "WadeMoneyCoreTests", dependencies: ["WadeMoneyCore"]),
    ]
)
```

- [ ] **Step 2: 실패하는 테스트 작성**

`WadeMoneyCore/Tests/WadeMoneyCoreTests/YearMonthTests.swift`:

```swift
import Testing
@testable import WadeMoneyCore

struct YearMonthTests {
    @Test func comparesByYearThenMonth() {
        #expect(YearMonth(year: 2026, month: 3) < YearMonth(year: 2026, month: 7))
        #expect(YearMonth(year: 2025, month: 12) < YearMonth(year: 2026, month: 1))
        #expect(!(YearMonth(year: 2026, month: 7) < YearMonth(year: 2026, month: 7)))
    }

    @Test func addingMonthsRollsOverYear() {
        #expect(YearMonth(year: 2026, month: 11).adding(months: 3) == YearMonth(year: 2027, month: 2))
        #expect(YearMonth(year: 2026, month: 1).adding(months: -1) == YearMonth(year: 2025, month: 12))
        #expect(YearMonth(year: 2026, month: 7).adding(months: 0) == YearMonth(year: 2026, month: 7))
    }
}
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `cd WadeMoneyCore && swift test`
Expected: FAIL — `cannot find 'YearMonth' in scope`

- [ ] **Step 4: 구현 작성**

`WadeMoneyCore/Sources/WadeMoneyCore/YearMonth.swift`:

```swift
public struct YearMonth: Equatable, Comparable, Hashable, Sendable {
    public let year: Int
    public let month: Int   // 1...12

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    public static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        return lhs.month < rhs.month
    }

    /// 지정한 개월 수를 더한 YearMonth. 음수 가능.
    public func adding(months: Int) -> YearMonth {
        let zeroBased = year * 12 + (month - 1) + months
        let y = Int((Double(zeroBased) / 12.0).rounded(.down))
        let m = zeroBased - y * 12 + 1
        return YearMonth(year: y, month: m)
    }
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `cd WadeMoneyCore && swift test`
Expected: PASS (2 tests)

- [ ] **Step 6: 커밋**

```bash
git add WadeMoneyCore
git commit -m "feat(core): scaffold WadeMoneyCore package with YearMonth"
```

---

### Task 2: 도메인 값 타입

거래·카테고리·설정·감정 태그 등 엔진이 다루는 공용 어휘를 정의한다.

**Files:**
- Create: `WadeMoneyCore/Sources/WadeMoneyCore/Domain.swift`
- Create: `WadeMoneyCore/Sources/WadeMoneyCore/Decimal+Double.swift`
- Test: `WadeMoneyCore/Tests/WadeMoneyCoreTests/DomainTests.swift`

**Interfaces:**
- Consumes: (없음)
- Produces:
  - `enum TransactionType: Sendable { case expense, income }`
  - `struct TransactionRecord: Identifiable, Equatable, Sendable { let id: UUID; var amount: Decimal; var type: TransactionType; var categoryID: UUID?; var memo: String?; var date: Date; var createdAt: Date; init(id:amount:type:categoryID:memo:date:createdAt:) }`
  - `struct CategoryRef: Identifiable, Equatable, Sendable { let id: UUID; var name: String; var iconName: String; var colorHex: String; var sortOrder: Int; var isArchived: Bool; init(...) }`
  - `struct EngineSettings: Sendable { var monthStartDay: Int; var aiEnabled: Bool; init(monthStartDay:aiEnabled:) }`
  - `extension Decimal { var doubleValue: Double }`

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyCore/Tests/WadeMoneyCoreTests/DomainTests.swift`:

```swift
import Foundation
import Testing
@testable import WadeMoneyCore

struct DomainTests {
    @Test func transactionDefaultsAreExpense() {
        let t = TransactionRecord(amount: 4800, date: Date(timeIntervalSince1970: 0))
        #expect(t.type == .expense)
        #expect(t.categoryID == nil)
        #expect(t.amount == 4800)
    }

    @Test func decimalConvertsToDouble() {
        #expect(Decimal(string: "0.25")!.doubleValue == 0.25)
        #expect(Decimal(150).doubleValue == 150.0)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd WadeMoneyCore && swift test`
Expected: FAIL — `cannot find 'TransactionRecord' in scope`

- [ ] **Step 3: 구현 작성 — 도메인 타입**

`WadeMoneyCore/Sources/WadeMoneyCore/Domain.swift`:

```swift
import Foundation

public enum TransactionType: Sendable, Equatable {
    case expense
    case income
}

public struct TransactionRecord: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var amount: Decimal
    public var type: TransactionType
    public var categoryID: UUID?
    public var memo: String?
    public var date: Date
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        amount: Decimal,
        type: TransactionType = .expense,
        categoryID: UUID? = nil,
        memo: String? = nil,
        date: Date,
        createdAt: Date = .init(timeIntervalSince1970: 0)
    ) {
        self.id = id
        self.amount = amount
        self.type = type
        self.categoryID = categoryID
        self.memo = memo
        self.date = date
        self.createdAt = createdAt
    }
}

public struct CategoryRef: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var iconName: String
    public var colorHex: String
    public var sortOrder: Int
    public var isArchived: Bool

    public init(
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

public struct EngineSettings: Sendable, Equatable {
    public var monthStartDay: Int
    public var aiEnabled: Bool

    public init(monthStartDay: Int = 1, aiEnabled: Bool = true) {
        self.monthStartDay = monthStartDay
        self.aiEnabled = aiEnabled
    }
}
```

- [ ] **Step 4: 구현 작성 — Decimal→Double**

`WadeMoneyCore/Sources/WadeMoneyCore/Decimal+Double.swift`:

```swift
import Foundation

extension Decimal {
    public var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `cd WadeMoneyCore && swift test`
Expected: PASS (누적 4 tests)

- [ ] **Step 6: 커밋**

```bash
git add WadeMoneyCore
git commit -m "feat(core): add domain value types and Decimal helper"
```

---

### Task 3: `PeriodCalculator` — 기간 경계 계산

일/월/연 구간, 이전 구간, 경과일수(D), 구간 일수를 `monthStartDay` 기준으로 계산한다.

**Files:**
- Create: `WadeMoneyCore/Sources/WadeMoneyCore/Period.swift`
- Test: `WadeMoneyCore/Tests/WadeMoneyCoreTests/PeriodCalculatorTests.swift`
- Create (테스트 헬퍼): `WadeMoneyCore/Tests/WadeMoneyCoreTests/TestSupport.swift`

**Interfaces:**
- Consumes: (없음)
- Produces:
  - `enum PeriodKind: Sendable { case day, month, year }`
  - `struct Period: Equatable, Sendable { let kind: PeriodKind; let start: Date; let end: Date }`
  - `struct PeriodCalculator: Sendable { let calendar: Calendar; let monthStartDay: Int; init(calendar:monthStartDay:); func period(_:containing:) -> Period; func period(_:offset:from:) -> Period; func previous(_:) -> Period; func dayCount(of:) -> Int; func daysElapsed(in:asOf:) -> Int }`

- [ ] **Step 1: 테스트 헬퍼 작성**

`WadeMoneyCore/Tests/WadeMoneyCoreTests/TestSupport.swift`:

```swift
import Foundation
@testable import WadeMoneyCore

enum TS {
    /// 결정적 테스트용 UTC 그레고리안 캘린더.
    static var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    /// UTC 자정 기준 날짜.
    static func date(_ y: Int, _ m: Int, _ d: Int, _ hh: Int = 0, _ mm: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = hh; comps.minute = mm
        return utc.date(from: comps)!
    }
}
```

- [ ] **Step 2: 실패하는 테스트 작성**

`WadeMoneyCore/Tests/WadeMoneyCoreTests/PeriodCalculatorTests.swift`:

```swift
import Foundation
import Testing
@testable import WadeMoneyCore

struct PeriodCalculatorTests {
    let cal = PeriodCalculator(calendar: TS.utc, monthStartDay: 1)

    @Test func monthPeriodIsCalendarMonthWhenStartDayIsOne() {
        let p = cal.period(.month, containing: TS.date(2026, 7, 15))
        #expect(p.start == TS.date(2026, 7, 1))
        #expect(p.end == TS.date(2026, 8, 1))
        #expect(cal.dayCount(of: p) == 31)
    }

    @Test func dayPeriodIsSingleDay() {
        let p = cal.period(.day, containing: TS.date(2026, 7, 15, 14, 20))
        #expect(p.start == TS.date(2026, 7, 15))
        #expect(p.end == TS.date(2026, 7, 16))
        #expect(cal.dayCount(of: p) == 1)
    }

    @Test func yearPeriodIsCalendarYearWhenStartDayIsOne() {
        let p = cal.period(.year, containing: TS.date(2026, 7, 15))
        #expect(p.start == TS.date(2026, 1, 1))
        #expect(p.end == TS.date(2027, 1, 1))
    }

    @Test func customMonthStartDayShiftsBoundaries() {
        let c = PeriodCalculator(calendar: TS.utc, monthStartDay: 25)
        // 7월 10일은 6/25~7/25 구간에 속한다
        let p = c.period(.month, containing: TS.date(2026, 7, 10))
        #expect(p.start == TS.date(2026, 6, 25))
        #expect(p.end == TS.date(2026, 7, 25))
        // 7월 25일은 다음 구간의 시작
        let p2 = c.period(.month, containing: TS.date(2026, 7, 25))
        #expect(p2.start == TS.date(2026, 7, 25))
    }

    @Test func offsetNavigatesPeriods() {
        let base = cal.period(.month, containing: TS.date(2026, 7, 15))
        let prev = cal.period(.month, offset: -1, from: base.start)
        #expect(prev.start == TS.date(2026, 6, 1))
        #expect(prev.end == TS.date(2026, 7, 1))
        let next = cal.period(.month, offset: 1, from: base.start)
        #expect(next.start == TS.date(2026, 8, 1))
    }

    @Test func previousReturnsPrecedingPeriod() {
        let p = cal.period(.month, containing: TS.date(2026, 1, 10))
        let prev = cal.previous(p)
        #expect(prev.start == TS.date(2025, 12, 1))
    }

    @Test func daysElapsedIsInclusiveAndCapped() {
        let p = cal.period(.month, containing: TS.date(2026, 7, 1))
        // 7월 15일 기준 → 1~15일 = 15일
        #expect(cal.daysElapsed(in: p, asOf: TS.date(2026, 7, 15, 23, 0)) == 15)
        // 구간 이전
        #expect(cal.daysElapsed(in: p, asOf: TS.date(2026, 6, 20)) == 0)
        // 구간 종료 이후 → 전체 길이(31)
        #expect(cal.daysElapsed(in: p, asOf: TS.date(2026, 9, 1)) == 31)
    }
}
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `cd WadeMoneyCore && swift test`
Expected: FAIL — `cannot find 'PeriodCalculator' in scope`

- [ ] **Step 4: 구현 작성**

`WadeMoneyCore/Sources/WadeMoneyCore/Period.swift`:

```swift
import Foundation

public enum PeriodKind: Sendable, Equatable {
    case day
    case month
    case year
}

public struct Period: Equatable, Sendable {
    public let kind: PeriodKind
    public let start: Date   // inclusive
    public let end: Date     // exclusive

    public init(kind: PeriodKind, start: Date, end: Date) {
        self.kind = kind
        self.start = start
        self.end = end
    }
}

public struct PeriodCalculator: Sendable {
    public let calendar: Calendar
    public let monthStartDay: Int   // 1...28

    public init(calendar: Calendar, monthStartDay: Int = 1) {
        self.calendar = calendar
        self.monthStartDay = min(max(monthStartDay, 1), 28)
    }

    public func period(_ kind: PeriodKind, containing date: Date) -> Period {
        switch kind {
        case .day:   return dayPeriod(containing: date)
        case .month: return monthPeriod(containing: date)
        case .year:  return yearPeriod(containing: date)
        }
    }

    public func period(_ kind: PeriodKind, offset n: Int, from date: Date) -> Period {
        let base = period(kind, containing: date)
        let component: Calendar.Component = {
            switch kind {
            case .day: return .day
            case .month: return .month
            case .year: return .year
            }
        }()
        let shifted = calendar.date(byAdding: component, value: n, to: base.start)!
        return period(kind, containing: shifted)
    }

    public func previous(_ p: Period) -> Period {
        period(p.kind, offset: -1, from: p.start)
    }

    public func dayCount(of p: Period) -> Int {
        calendar.dateComponents([.day], from: p.start, to: p.end).day ?? 0
    }

    /// 구간 시작부터 now가 속한 날까지 경과 일수(당일 포함). 구간 이전이면 0, 구간 종료 이후면 전체 길이.
    public func daysElapsed(in p: Period, asOf now: Date) -> Int {
        if now < p.start { return 0 }
        if now >= p.end { return dayCount(of: p) }
        let startDay = calendar.startOfDay(for: p.start)
        let nowDay = calendar.startOfDay(for: now)
        let diff = calendar.dateComponents([.day], from: startDay, to: nowDay).day ?? 0
        return diff + 1
    }

    // MARK: - Private

    private func dayPeriod(containing date: Date) -> Period {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return Period(kind: .day, start: start, end: end)
    }

    private func monthPeriod(containing date: Date) -> Period {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        var startComps = DateComponents()
        startComps.year = comps.year
        startComps.month = comps.month
        startComps.day = monthStartDay
        var start = calendar.startOfDay(for: calendar.date(from: startComps)!)
        if (comps.day ?? 1) < monthStartDay {
            start = calendar.date(byAdding: .month, value: -1, to: start)!
        }
        let end = calendar.date(byAdding: .month, value: 1, to: start)!
        return Period(kind: .month, start: start, end: end)
    }

    private func yearPeriod(containing date: Date) -> Period {
        let m = monthPeriod(containing: date)
        let startYear = calendar.component(.year, from: m.start)
        var janComps = DateComponents()
        janComps.year = startYear
        janComps.month = 1
        janComps.day = monthStartDay
        let start = calendar.startOfDay(for: calendar.date(from: janComps)!)
        let end = calendar.date(byAdding: .year, value: 1, to: start)!
        return Period(kind: .year, start: start, end: end)
    }
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `cd WadeMoneyCore && swift test`
Expected: PASS (누적 11 tests)

- [ ] **Step 6: 커밋**

```bash
git add WadeMoneyCore
git commit -m "feat(core): add PeriodCalculator with monthStartDay boundaries"
```

---

### Task 4: `BudgetBook` — 월별 예산 스냅샷 해석

**Files:**
- Create: `WadeMoneyCore/Sources/WadeMoneyCore/BudgetBook.swift`
- Test: `WadeMoneyCore/Tests/WadeMoneyCoreTests/BudgetBookTests.swift`

**Interfaces:**
- Consumes: `YearMonth`, `PeriodCalculator`, `Period`
- Produces:
  - `struct BudgetSnapshot: Equatable, Sendable { let effectiveMonth: YearMonth; let amount: Decimal; init(effectiveMonth:amount:) }`
  - `struct BudgetBook: Sendable { init(_ snapshots: [BudgetSnapshot]); func amount(for: YearMonth) -> Decimal?; func monthlyAmount(on: Date, calc: PeriodCalculator) -> Decimal?; func dailyAmount(on: Date, calc: PeriodCalculator) -> Decimal?; func yearAmount(on: Date, calc: PeriodCalculator) -> Decimal? }`

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyCore/Tests/WadeMoneyCoreTests/BudgetBookTests.swift`:

```swift
import Foundation
import Testing
@testable import WadeMoneyCore

struct BudgetBookTests {
    let cal = PeriodCalculator(calendar: TS.utc, monthStartDay: 1)

    // 2026-05부터 100만, 2026-07부터 130만
    var book: BudgetBook {
        BudgetBook([
            BudgetSnapshot(effectiveMonth: YearMonth(year: 2026, month: 5), amount: 1_000_000),
            BudgetSnapshot(effectiveMonth: YearMonth(year: 2026, month: 7), amount: 1_300_000),
        ])
    }

    @Test func picksMostRecentEffectiveSnapshot() {
        #expect(book.amount(for: YearMonth(year: 2026, month: 6)) == 1_000_000)
        #expect(book.amount(for: YearMonth(year: 2026, month: 7)) == 1_300_000)
        #expect(book.amount(for: YearMonth(year: 2026, month: 9)) == 1_300_000)
    }

    @Test func returnsNilBeforeFirstSnapshot() {
        #expect(book.amount(for: YearMonth(year: 2026, month: 4)) == nil)
    }

    @Test func monthlyAmountResolvesByPeriodStart() {
        #expect(book.monthlyAmount(on: TS.date(2026, 7, 15), calc: cal) == 1_300_000)
        #expect(book.monthlyAmount(on: TS.date(2026, 6, 2), calc: cal) == 1_000_000)
    }

    @Test func dailyAmountDividesByDaysInMonth() {
        // 7월(31일) 130만 → 일예산 = 1_300_000 / 31
        let daily = book.dailyAmount(on: TS.date(2026, 7, 15), calc: cal)!
        #expect(daily == Decimal(1_300_000) / Decimal(31))
    }

    @Test func yearAmountSumsMonthlySnapshots() {
        // 2026: 1~4월 없음(nil→0 취급), 5·6월 100만, 7~12월 130만
        // = 2*100만 + 6*130만 = 200만 + 780만 = 980만
        let y = book.yearAmount(on: TS.date(2026, 7, 15), calc: cal)!
        #expect(y == 9_800_000)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd WadeMoneyCore && swift test`
Expected: FAIL — `cannot find 'BudgetBook' in scope`

- [ ] **Step 3: 구현 작성**

`WadeMoneyCore/Sources/WadeMoneyCore/BudgetBook.swift`:

```swift
import Foundation

public struct BudgetSnapshot: Equatable, Sendable {
    public let effectiveMonth: YearMonth
    public let amount: Decimal

    public init(effectiveMonth: YearMonth, amount: Decimal) {
        self.effectiveMonth = effectiveMonth
        self.amount = amount
    }
}

public struct BudgetBook: Sendable {
    private let snapshots: [BudgetSnapshot]   // effectiveMonth 오름차순

    public init(_ snapshots: [BudgetSnapshot]) {
        self.snapshots = snapshots.sorted { $0.effectiveMonth < $1.effectiveMonth }
    }

    /// 해당 월 이하 중 가장 최근 effectiveMonth의 금액.
    public func amount(for ym: YearMonth) -> Decimal? {
        snapshots.last { $0.effectiveMonth <= ym }?.amount
    }

    public func monthlyAmount(on date: Date, calc: PeriodCalculator) -> Decimal? {
        amount(for: yearMonth(ofPeriodStart: calc.period(.month, containing: date), calc: calc))
    }

    public func dailyAmount(on date: Date, calc: PeriodCalculator) -> Decimal? {
        let period = calc.period(.month, containing: date)
        guard let monthly = amount(for: yearMonth(ofPeriodStart: period, calc: calc)) else { return nil }
        let days = calc.dayCount(of: period)
        guard days > 0 else { return nil }
        return monthly / Decimal(days)
    }

    /// 그 해 12개 예산월 금액의 합. 스냅샷 없는 월은 0으로 취급. 모든 월이 없으면 nil.
    public func yearAmount(on date: Date, calc: PeriodCalculator) -> Decimal? {
        let year = calc.period(.year, containing: date)
        var total = Decimal(0)
        var any = false
        var cursor = year.start
        while cursor < year.end {
            let ym = YearMonth(
                year: calc.calendar.component(.year, from: cursor),
                month: calc.calendar.component(.month, from: cursor)
            )
            if let a = amount(for: ym) {
                total += a
                any = true
            }
            cursor = calc.calendar.date(byAdding: .month, value: 1, to: cursor)!
        }
        return any ? total : nil
    }

    private func yearMonth(ofPeriodStart period: Period, calc: PeriodCalculator) -> YearMonth {
        YearMonth(
            year: calc.calendar.component(.year, from: period.start),
            month: calc.calendar.component(.month, from: period.start)
        )
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd WadeMoneyCore && swift test`
Expected: PASS (누적 16 tests)

- [ ] **Step 5: 커밋**

```bash
git add WadeMoneyCore
git commit -m "feat(core): add BudgetBook snapshot resolution"
```

---

### Task 5: `Aggregator` — 지출 집계 & 카테고리별 합계

**Files:**
- Create: `WadeMoneyCore/Sources/WadeMoneyCore/Aggregator.swift`
- Test: `WadeMoneyCore/Tests/WadeMoneyCoreTests/AggregatorTests.swift`

**Interfaces:**
- Consumes: `TransactionRecord`, `Period`
- Produces:
  - `struct CategoryTotal: Equatable, Sendable { let categoryID: UUID?; let total: Decimal }`
  - `enum Aggregator { static func totalExpense(_:in:) -> Decimal; static func totalExpense(_:from:to:) -> Decimal; static func totalIncome(_:in:) -> Decimal; static func totalsByCategory(_:in:) -> [CategoryTotal] }`
  - `totalsByCategory`는 지출만, 합계 내림차순 정렬해 반환.

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyCore/Tests/WadeMoneyCoreTests/AggregatorTests.swift`:

```swift
import Foundation
import Testing
@testable import WadeMoneyCore

struct AggregatorTests {
    let cal = PeriodCalculator(calendar: TS.utc, monthStartDay: 1)
    let food = UUID()
    let cafe = UUID()

    func txns() -> [TransactionRecord] {
        [
            TransactionRecord(amount: 9000, type: .expense, categoryID: food, date: TS.date(2026, 7, 2)),
            TransactionRecord(amount: 4800, type: .expense, categoryID: cafe, date: TS.date(2026, 7, 3)),
            TransactionRecord(amount: 3200, type: .expense, categoryID: cafe, date: TS.date(2026, 7, 4)),
            TransactionRecord(amount: 45000, type: .income, categoryID: nil, date: TS.date(2026, 7, 5)),
            // 구간 밖
            TransactionRecord(amount: 5000, type: .expense, categoryID: food, date: TS.date(2026, 6, 30)),
        ]
    }

    @Test func totalExpenseIgnoresIncomeAndOutOfRange() {
        let p = cal.period(.month, containing: TS.date(2026, 7, 1))
        #expect(Aggregator.totalExpense(txns(), in: p) == 17000)   // 9000+4800+3200
    }

    @Test func totalIncomeSumsIncomeOnly() {
        let p = cal.period(.month, containing: TS.date(2026, 7, 1))
        #expect(Aggregator.totalIncome(txns(), in: p) == 45000)
    }

    @Test func totalExpenseByExplicitInterval() {
        // 7/1 00:00 ~ 7/4 00:00 → 7/2, 7/3만 포함
        let sum = Aggregator.totalExpense(txns(), from: TS.date(2026, 7, 1), to: TS.date(2026, 7, 4))
        #expect(sum == 13800)   // 9000 + 4800
    }

    @Test func totalsByCategoryGroupsAndSortsDescending() {
        let p = cal.period(.month, containing: TS.date(2026, 7, 1))
        let totals = Aggregator.totalsByCategory(txns(), in: p)
        #expect(totals.count == 2)
        #expect(totals[0] == CategoryTotal(categoryID: food, total: 9000))   // 최대 먼저
        #expect(totals[1] == CategoryTotal(categoryID: cafe, total: 8000))   // 4800+3200
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd WadeMoneyCore && swift test`
Expected: FAIL — `cannot find 'Aggregator' in scope`

- [ ] **Step 3: 구현 작성**

`WadeMoneyCore/Sources/WadeMoneyCore/Aggregator.swift`:

```swift
import Foundation

public struct CategoryTotal: Equatable, Sendable {
    public let categoryID: UUID?
    public let total: Decimal

    public init(categoryID: UUID?, total: Decimal) {
        self.categoryID = categoryID
        self.total = total
    }
}

public enum Aggregator {
    public static func totalExpense(_ txns: [TransactionRecord], in period: Period) -> Decimal {
        totalExpense(txns, from: period.start, to: period.end)
    }

    public static func totalExpense(_ txns: [TransactionRecord], from start: Date, to end: Date) -> Decimal {
        txns.reduce(Decimal(0)) { acc, t in
            guard t.type == .expense, t.date >= start, t.date < end else { return acc }
            return acc + t.amount
        }
    }

    public static func totalIncome(_ txns: [TransactionRecord], in period: Period) -> Decimal {
        txns.reduce(Decimal(0)) { acc, t in
            guard t.type == .income, t.date >= period.start, t.date < period.end else { return acc }
            return acc + t.amount
        }
    }

    /// 지출만 카테고리별 합계. 합계 내림차순.
    public static func totalsByCategory(_ txns: [TransactionRecord], in period: Period) -> [CategoryTotal] {
        var buckets: [UUID?: Decimal] = [:]
        for t in txns where t.type == .expense && t.date >= period.start && t.date < period.end {
            buckets[t.categoryID, default: 0] += t.amount
        }
        return buckets
            .map { CategoryTotal(categoryID: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd WadeMoneyCore && swift test`
Expected: PASS (누적 20 tests)

> 참고: `totalsByCategory`의 동점(같은 total) 정렬 순서는 비결정적일 수 있으나, 테스트 데이터는 동점이 없다. 앱 계층에서 표시 시 카테고리 `sortOrder`로 2차 정렬한다(계획 3).

- [ ] **Step 5: 커밋**

```bash
git add WadeMoneyCore
git commit -m "feat(core): add Aggregator for expense sums and category totals"
```

---

### Task 6: `PaceCalculator` — "지난 기간 같은 시점 대비"

**Files:**
- Create: `WadeMoneyCore/Sources/WadeMoneyCore/PaceCalculator.swift`
- Test: `WadeMoneyCore/Tests/WadeMoneyCoreTests/PaceCalculatorTests.swift`

**Interfaces:**
- Consumes: `PeriodCalculator`, `Aggregator`, `TransactionRecord`, `PeriodKind`
- Produces:
  - `struct PaceResult: Equatable, Sendable { let currentCumulative: Decimal; let priorCumulative: Decimal; let deltaRatio: Decimal?; var isComparable: Bool }`
  - `struct PaceCalculator: Sendable { init(calc: PeriodCalculator); func pace(kind:containing:asOf:txns:) -> PaceResult }`

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyCore/Tests/WadeMoneyCoreTests/PaceCalculatorTests.swift`:

```swift
import Foundation
import Testing
@testable import WadeMoneyCore

struct PaceCalculatorTests {
    let calc = PeriodCalculator(calendar: TS.utc, monthStartDay: 1)
    var pace: PaceCalculator { PaceCalculator(calc: calc) }
    let food = UUID()

    @Test func comparesCurrentToPriorSamePoint() {
        // 6월: 1~15일 누적 10만, 7월: 1~15일 누적 12만
        let txns = [
            TransactionRecord(amount: 100_000, type: .expense, categoryID: food, date: TS.date(2026, 6, 5)),
            TransactionRecord(amount: 999_999, type: .expense, categoryID: food, date: TS.date(2026, 6, 20)), // D 이후 → 제외
            TransactionRecord(amount: 120_000, type: .expense, categoryID: food, date: TS.date(2026, 7, 10)),
        ]
        let r = pace.pace(kind: .month, containing: TS.date(2026, 7, 1), asOf: TS.date(2026, 7, 15, 12), txns: txns)
        #expect(r.currentCumulative == 120_000)
        #expect(r.priorCumulative == 100_000)
        #expect(r.deltaRatio == Decimal(20_000) / Decimal(100_000))   // +0.2
        #expect(r.isComparable)
    }

    @Test func notComparableWhenPriorIsZero() {
        // 첫 기간(이전 달 데이터 없음)
        let txns = [
            TransactionRecord(amount: 50_000, type: .expense, categoryID: food, date: TS.date(2026, 7, 3)),
        ]
        let r = pace.pace(kind: .month, containing: TS.date(2026, 7, 1), asOf: TS.date(2026, 7, 15), txns: txns)
        #expect(r.priorCumulative == 0)
        #expect(r.deltaRatio == nil)
        #expect(!r.isComparable)
    }

    @Test func priorIsCappedToShorterPriorPeriodLength() {
        // 완료된 3월(31일) vs 2월(28일). D는 3월 전체(31)지만 이전 구간은 28로 캡.
        let txns = [
            TransactionRecord(amount: 28_000, type: .expense, categoryID: food, date: TS.date(2026, 2, 27)),
            // 2월엔 29일이 없음. 3월 29~31일 지출은 캡 로직과 무관하게 current에 포함.
            TransactionRecord(amount: 31_000, type: .expense, categoryID: food, date: TS.date(2026, 3, 30)),
        ]
        // asOf가 구간 종료 이후 → D = 31(전체)
        let r = pace.pace(kind: .month, containing: TS.date(2026, 3, 1), asOf: TS.date(2026, 5, 1), txns: txns)
        #expect(r.currentCumulative == 31_000)
        #expect(r.priorCumulative == 28_000)   // 2월 전체
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd WadeMoneyCore && swift test`
Expected: FAIL — `cannot find 'PaceCalculator' in scope`

- [ ] **Step 3: 구현 작성**

`WadeMoneyCore/Sources/WadeMoneyCore/PaceCalculator.swift`:

```swift
import Foundation

public struct PaceResult: Equatable, Sendable {
    public let currentCumulative: Decimal
    public let priorCumulative: Decimal
    public let deltaRatio: Decimal?   // nil = 비교 불가

    public init(currentCumulative: Decimal, priorCumulative: Decimal, deltaRatio: Decimal?) {
        self.currentCumulative = currentCumulative
        self.priorCumulative = priorCumulative
        self.deltaRatio = deltaRatio
    }

    public var isComparable: Bool { deltaRatio != nil }
}

public struct PaceCalculator: Sendable {
    private let calc: PeriodCalculator

    public init(calc: PeriodCalculator) {
        self.calc = calc
    }

    public func pace(
        kind: PeriodKind,
        containing date: Date,
        asOf now: Date,
        txns: [TransactionRecord]
    ) -> PaceResult {
        let current = calc.period(kind, containing: date)
        let d = calc.daysElapsed(in: current, asOf: now)

        let currentEnd = calc.calendar.date(byAdding: .day, value: d, to: current.start)!
        let currentSum = Aggregator.totalExpense(txns, from: current.start, to: currentEnd)

        let prior = calc.previous(current)
        let priorLength = calc.dayCount(of: prior)
        let priorD = min(d, priorLength)
        let priorEnd = calc.calendar.date(byAdding: .day, value: priorD, to: prior.start)!
        let priorSum = Aggregator.totalExpense(txns, from: prior.start, to: priorEnd)

        let ratio: Decimal? = priorSum == 0 ? nil : (currentSum - priorSum) / priorSum
        return PaceResult(currentCumulative: currentSum, priorCumulative: priorSum, deltaRatio: ratio)
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd WadeMoneyCore && swift test`
Expected: PASS (누적 23 tests)

- [ ] **Step 5: 커밋**

```bash
git add WadeMoneyCore
git commit -m "feat(core): add PaceCalculator for same-point comparison"
```

---

### Task 7: `Donut` 그룹핑 + `Projection` 예상 지출

**Files:**
- Create: `WadeMoneyCore/Sources/WadeMoneyCore/Donut.swift`
- Create: `WadeMoneyCore/Sources/WadeMoneyCore/Projection.swift`
- Test: `WadeMoneyCore/Tests/WadeMoneyCoreTests/DonutTests.swift`
- Test: `WadeMoneyCore/Tests/WadeMoneyCoreTests/ProjectionTests.swift`

**Interfaces:**
- Consumes: `CategoryTotal`, `Decimal.doubleValue`
- Produces:
  - `struct DonutSlice: Equatable, Sendable { let categoryID: UUID?; let total: Decimal; let fraction: Double; let isOther: Bool }`
  - `enum Donut { static func slices(_:maxSlices:) -> [DonutSlice] }` — 상위 `maxSlices-1`개 + 나머지 병합(`isOther=true`, `categoryID=nil`). 총합 이하일 땐 병합 없음.
  - `enum Projection { static func projectedTotal(cumulative:daysElapsed:daysInPeriod:) -> Decimal }`

- [ ] **Step 1: 실패하는 도넛 테스트 작성**

`WadeMoneyCore/Tests/WadeMoneyCoreTests/DonutTests.swift`:

```swift
import Foundation
import Testing
@testable import WadeMoneyCore

struct DonutTests {
    func totals(_ values: [Decimal]) -> [CategoryTotal] {
        values.map { CategoryTotal(categoryID: UUID(), total: $0) }
    }

    @Test func noOtherSliceWhenWithinMax() {
        let slices = Donut.slices(totals([500, 300, 200]), maxSlices: 6)
        #expect(slices.count == 3)
        #expect(slices.allSatisfy { !$0.isOther })
        #expect(slices[0].fraction == 0.5)   // 500/1000
    }

    @Test func mergesOverflowIntoOtherSlice() {
        // 8개 → maxSlices 6이면 상위 5개 + 기타(나머지 3개 합)
        let slices = Donut.slices(totals([100, 90, 80, 70, 60, 50, 40, 10]), maxSlices: 6)
        #expect(slices.count == 6)
        #expect(slices[5].isOther)
        #expect(slices[5].categoryID == nil)
        #expect(slices[5].total == 100)   // 50+40+10
    }

    @Test func ignoresZeroAndReturnsEmptyWhenNoSpend() {
        #expect(Donut.slices(totals([0, 0]), maxSlices: 6).isEmpty)
        #expect(Donut.slices([], maxSlices: 6).isEmpty)
    }
}
```

- [ ] **Step 2: 실패하는 예상 테스트 작성**

`WadeMoneyCore/Tests/WadeMoneyCoreTests/ProjectionTests.swift`:

```swift
import Foundation
import Testing
@testable import WadeMoneyCore

struct ProjectionTests {
    @Test func scalesCumulativeToFullPeriod() {
        // 15일 동안 90만 → 30일 기준 180만
        #expect(Projection.projectedTotal(cumulative: 900_000, daysElapsed: 15, daysInPeriod: 30) == 1_800_000)
    }

    @Test func zeroElapsedReturnsZero() {
        #expect(Projection.projectedTotal(cumulative: 0, daysElapsed: 0, daysInPeriod: 30) == 0)
    }
}
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `cd WadeMoneyCore && swift test`
Expected: FAIL — `cannot find 'Donut'` / `cannot find 'Projection'`

- [ ] **Step 4: 구현 작성 — Donut**

`WadeMoneyCore/Sources/WadeMoneyCore/Donut.swift`:

```swift
import Foundation

public struct DonutSlice: Equatable, Sendable {
    public let categoryID: UUID?   // nil = 병합된 "기타" 슬라이스
    public let total: Decimal
    public let fraction: Double
    public let isOther: Bool

    public init(categoryID: UUID?, total: Decimal, fraction: Double, isOther: Bool) {
        self.categoryID = categoryID
        self.total = total
        self.fraction = fraction
        self.isOther = isOther
    }
}

public enum Donut {
    /// 상위 (maxSlices-1)개 + 나머지 병합. 0 이하 카테고리 제외.
    public static func slices(_ totals: [CategoryTotal], maxSlices: Int = 6) -> [DonutSlice] {
        let positive = totals.filter { $0.total > 0 }.sorted { $0.total > $1.total }
        let grand = positive.reduce(Decimal(0)) { $0 + $1.total }
        guard grand > 0 else { return [] }

        func fraction(_ value: Decimal) -> Double { (value / grand).doubleValue }

        if positive.count <= maxSlices {
            return positive.map {
                DonutSlice(categoryID: $0.categoryID, total: $0.total, fraction: fraction($0.total), isOther: false)
            }
        }

        let head = positive.prefix(maxSlices - 1)
        let tail = positive.dropFirst(maxSlices - 1)
        var result = head.map {
            DonutSlice(categoryID: $0.categoryID, total: $0.total, fraction: fraction($0.total), isOther: false)
        }
        let otherTotal = tail.reduce(Decimal(0)) { $0 + $1.total }
        result.append(DonutSlice(categoryID: nil, total: otherTotal, fraction: fraction(otherTotal), isOther: true))
        return result
    }
}
```

- [ ] **Step 5: 구현 작성 — Projection**

`WadeMoneyCore/Sources/WadeMoneyCore/Projection.swift`:

```swift
import Foundation

public enum Projection {
    /// 현재 누적을 전체 기간으로 선형 환산. 경과일이 0이면 0.
    public static func projectedTotal(cumulative: Decimal, daysElapsed: Int, daysInPeriod: Int) -> Decimal {
        guard daysElapsed > 0 else { return 0 }
        return cumulative / Decimal(daysElapsed) * Decimal(daysInPeriod)
    }
}
```

- [ ] **Step 6: 테스트 통과 확인**

Run: `cd WadeMoneyCore && swift test`
Expected: PASS (누적 28 tests)

- [ ] **Step 7: 커밋**

```bash
git add WadeMoneyCore
git commit -m "feat(core): add Donut grouping and Projection"
```

---

## Self-Review (계획 작성자 확인 완료)

- **스펙 커버리지**: 스펙 §5.1 기간 정의→Task 3, §5.2 예산 진행(월/일/연 금액)→Task 4, §5.3 페이스→Task 6, §5.4 도넛(상위6+기타)→Task 7, §5.6 예상→Task 7, §4 데이터 모델 값 타입→Task 2. 집계(총지출·카테고리별)→Task 5. **UI 렌더링·소진율%·색상은 이 계획 범위 밖**(계획 3). **소진율 = 지출합÷예산**은 순수 나눗셈이라 앱 계층에서 `Aggregator.totalExpense / BudgetBook.*Amount`로 조합 — 별도 엔진 함수 불필요.
- **플레이스홀더 스캔**: 없음. 모든 스텝에 실제 코드/명령 포함.
- **타입 일관성**: `PeriodCalculator.period(_:containing:)`·`period(_:offset:from:)`·`previous`·`dayCount(of:)`·`daysElapsed(in:asOf:)`, `Aggregator.totalExpense(_:from:to:)`, `BudgetBook.monthlyAmount/dailyAmount/yearAmount(on:calc:)`, `CategoryTotal`, `DonutSlice`, `PaceResult` 시그니처가 태스크 간 일치.

## 다음 계획으로의 인터페이스

계획 2(영속화·앱 셸)는 SwiftData `@Model`을 위 값 타입으로 매핑한다:
- `Transaction`(@Model) ↔ `TransactionRecord`
- `Category`(@Model) ↔ `CategoryRef`
- `MonthlyBudget`(@Model) ↔ `BudgetSnapshot` → `BudgetBook`
- `AppSettings`(@Model) ↔ `EngineSettings`
그리고 `Date()` / `Calendar.current`(사용자 로컬 타임존)를 주입해 엔진을 호출한다.
