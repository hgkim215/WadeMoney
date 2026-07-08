# CloudKit Sync Status Visibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface real CloudKit sync state (normal / importing / unavailable) on the dashboard and settings screen instead of a hardcoded "always working" label, and let users confirm their data is backed up before deleting the app.

**Architecture:** A single `@MainActor @Observable` `CloudSyncMonitor`, constructed once in `WadeMoneyApp.init()` and injected via `.environment(_:)`, tracks sync state from (a) whether the CloudKit-backed `ModelContainer` was actually created, (b) whether the device is signed into iCloud (`FileManager.ubiquityIdentityToken`), and (c) live `NSPersistentCloudKitContainer.eventChangedNotification` events. `DashboardScreen` and `SettingsScreen` both read the same instance.

**Tech Stack:** SwiftUI, SwiftData, CoreData (`NSPersistentCloudKitContainer` notifications only — SwiftData still owns the `ModelContainer`), Swift Testing.

## Global Constraints

- No new color tokens — reuse `WadeColors`/`WadeFont`/`WadeSpacing`/`WadeRadius` only.
- No CloudKit-record-count-based percentage UI — indeterminate animation only.
- No "force sync now" feature — no such public API exists; the backup-check button reads current state only.
- No runtime `ModelContainer` recreation/swap.
- No copy telling the user to restart the app.
- Custom category duplicate merge is automatic/deterministic — no user confirmation UI.
- Test simulator: **iPhone 17e** (not iPhone 17 Pro) for all `xcodebuild test`/`build` commands.
- Spec: `docs/superpowers/specs/2026-07-08-cloudkit-sync-status-visibility-design.md`

---

### Task 1: Generalize category duplicate merge to all categories

**Files:**
- Modify: `WadeMoney/Persistence/CategorySeeder.swift:53-76` (the function only — line 77 is the enum's own closing brace, do not touch it)
- Modify: `WadeMoney/WadeMoneyApp.swift:30`
- Modify: `WadeMoneyTests/CategorySeederTests.swift:59-89`

**Interfaces:**
- Produces: `CategorySeeder.reconcileDuplicateCategories(_ context: ModelContext) throws` (replaces `reconcileDuplicateDefaults`, same signature otherwise).

- [ ] **Step 1: Update the two existing tests that reference the old name/behavior, and add a custom-category case**

Replace lines 59-89 of `WadeMoneyTests/CategorySeederTests.swift`:

```swift
    @Test func reconcileMergesDuplicateDefaultsAndRepointsTransactions() throws {
        // 두 기기가 각자 시드한 뒤 CloudKit 병합 → 식비가 2개. 승자(id 최솟값)로 합치고 거래를 재연결.
        let c = try ctx()
        let a = CategoryModel(name: "식비", iconName: "restaurant", colorHex: "#E28A4E", sortOrder: 0)
        let b = CategoryModel(name: "식비", iconName: "restaurant", colorHex: "#E28A4E", sortOrder: 0)
        c.insert(a); c.insert(b)
        c.insert(TransactionModel(amount: 5000, type: .expense, category: b, memo: nil,
                                  date: Date(timeIntervalSince1970: 1_000_000), createdAt: Date(timeIntervalSince1970: 1_000_000)))
        try c.save()

        try CategorySeeder.reconcileDuplicateCategories(c)

        let remaining = try c.fetch(FetchDescriptor<CategoryModel>()).filter { $0.name == "식비" }
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == min(a.id, b.id))
        let txn = try c.fetch(FetchDescriptor<TransactionModel>()).first
        #expect(txn?.category?.id == min(a.id, b.id))   // 거래가 승자 카테고리로 이동
        _ = try #require(txn)
    }

    @Test func reconcileMergesDuplicateCustomCategoriesToo() throws {
        // 커스텀 카테고리도 이름이 같으면 병합 대상이다 (기본 카테고리만 다루던 이전 동작을 일반화).
        let c = try ctx()
        try CategorySeeder.seedIfNeeded(c)   // 기본 8종(중복 없음)
        c.insert(CategoryModel(name: "구독", iconName: "category", colorHex: "#000000", sortOrder: 8))
        c.insert(CategoryModel(name: "구독", iconName: "category", colorHex: "#000000", sortOrder: 9))
        try c.save()

        try CategorySeeder.reconcileDuplicateCategories(c)

        let remaining = try c.fetch(FetchDescriptor<CategoryModel>()).filter { $0.name == "구독" }
        #expect(remaining.count == 1)
        #expect(try c.fetchCount(FetchDescriptor<CategoryModel>()) == 9)   // 기본 8 + 구독 1(병합됨)
    }
```

- [ ] **Step 2: Run tests to verify they fail (function doesn't exist yet under the new name)**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/CategorySeederTests`
Expected: FAIL — build error, `reconcileDuplicateCategories` not found in scope.

- [ ] **Step 3: Rename and generalize the function**

Replace lines 53-76 of `WadeMoney/Persistence/CategorySeeder.swift` (the function body only — leave line 77, the enum's closing `}`, untouched):

```swift
    /// 여러 기기가 CloudKit으로 병합되면 이름이 같은 카테고리가 중복 생성될 수 있다(기본 카테고리든 커스텀 카테고리든).
    /// 이름이 같은 카테고리를 id 최솟값 행으로 결정적으로 합치고(거래 재연결), 나머지를 지운다.
    /// 모든 기기가 같은 승자를 고르므로 동기화 후 상태가 수렴한다. 멱등 — 매 실행 시 호출해도 안전.
    static func reconcileDuplicateCategories(_ context: ModelContext) throws {
        let all = try context.fetch(FetchDescriptor<CategoryModel>())
        let grouped = Dictionary(grouping: all, by: \.name)

        var changed = false
        for (_, rows) in grouped where rows.count > 1 {
            let sorted = rows.sorted { $0.id < $1.id }
            let winner = sorted[0]
            for loser in sorted.dropFirst() {
                let loserID = loser.id
                let orphans = try context.fetch(
                    FetchDescriptor<TransactionModel>(predicate: #Predicate { $0.category?.id == loserID })
                )
                for txn in orphans { txn.category = winner }
                context.delete(loser)
                changed = true
            }
        }
        if changed { try context.save() }
    }
```

- [ ] **Step 4: Update the call site**

In `WadeMoney/WadeMoneyApp.swift:30`, change:
```swift
        try? CategorySeeder.reconcileDuplicateDefaults(resolved.mainContext)
```
to:
```swift
        try? CategorySeeder.reconcileDuplicateCategories(resolved.mainContext)
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/CategorySeederTests`
Expected: PASS — all `CategorySeederTests` cases green, including the two updated/new ones.

- [ ] **Step 6: Commit**

```bash
git add WadeMoney/Persistence/CategorySeeder.swift WadeMoney/WadeMoneyApp.swift WadeMoneyTests/CategorySeederTests.swift
git commit -m "feat(sync): merge duplicate categories by name, not just defaults"
```

---

### Task 2: `CloudSyncMonitor` state machine (pure logic)

**Files:**
- Create: `WadeMoney/Persistence/CloudSyncMonitor.swift`
- Test: `WadeMoneyTests/CloudSyncMonitorTests.swift`

**Interfaces:**
- Produces: `CloudSyncMonitor` (`@MainActor @Observable final class`), nested `CloudSyncMonitor.State` enum (`.normal`, `.importing`, `.unavailable`, `Equatable`), `init(cloudKitEnabled: Bool, isSignedIntoiCloud: Bool, hasExistingData: Bool)`, `private(set) var state: State`, `private(set) var pendingExport: Bool`, `static func initialState(cloudKitEnabled:isSignedIntoiCloud:hasExistingData:) -> State`, `static func nextState(current:eventType:isFinished:succeeded:) -> State`, `static func nextPendingExport(current:eventType:isFinished:succeeded:) -> Bool`.
- Consumed by: Task 3 (adds live wiring to this same file), Task 4 (`WadeMoneyApp` constructs it), Task 5/6 (`DashboardScreen`/`SettingsScreen` read `.state`/`.pendingExport`).

- [ ] **Step 1: Write the failing tests**

Create `WadeMoneyTests/CloudSyncMonitorTests.swift`:

```swift
import CoreData
import Testing
@testable import WadeMoney

@MainActor
struct CloudSyncMonitorTests {
    @Test func unavailableWhenCloudKitDisabled() {
        let state = CloudSyncMonitor.initialState(cloudKitEnabled: false, isSignedIntoiCloud: true, hasExistingData: true)
        #expect(state == .unavailable)
    }

    @Test func unavailableWhenNotSignedIntoiCloud() {
        let state = CloudSyncMonitor.initialState(cloudKitEnabled: true, isSignedIntoiCloud: false, hasExistingData: true)
        #expect(state == .unavailable)
    }

    @Test func importingWhenEnabledSignedInButNoLocalData() {
        let state = CloudSyncMonitor.initialState(cloudKitEnabled: true, isSignedIntoiCloud: true, hasExistingData: false)
        #expect(state == .importing)
    }

    @Test func normalWhenEnabledSignedInWithLocalData() {
        let state = CloudSyncMonitor.initialState(cloudKitEnabled: true, isSignedIntoiCloud: true, hasExistingData: true)
        #expect(state == .normal)
    }

    @Test func initUsesInitialStateRule() {
        let monitor = CloudSyncMonitor(cloudKitEnabled: true, isSignedIntoiCloud: true, hasExistingData: false)
        #expect(monitor.state == .importing)
        #expect(monitor.pendingExport == false)
    }

    @Test func nextStateIgnoresNonImportEvents() {
        let result = CloudSyncMonitor.nextState(current: .importing, eventType: .export, isFinished: true, succeeded: true)
        #expect(result == .importing)
    }

    @Test func nextStateIgnoresUnfinishedImport() {
        let result = CloudSyncMonitor.nextState(current: .importing, eventType: .import, isFinished: false, succeeded: true)
        #expect(result == .importing)
    }

    @Test func nextStateMovesToNormalOnSuccessfulImportCompletion() {
        let result = CloudSyncMonitor.nextState(current: .importing, eventType: .import, isFinished: true, succeeded: true)
        #expect(result == .normal)
    }

    @Test func nextStateMovesToUnavailableOnFailedImportCompletion() {
        let result = CloudSyncMonitor.nextState(current: .importing, eventType: .import, isFinished: true, succeeded: false)
        #expect(result == .unavailable)
    }

    @Test func nextPendingExportIgnoresImportEvents() {
        let result = CloudSyncMonitor.nextPendingExport(current: true, eventType: .import, isFinished: true, succeeded: true)
        #expect(result == true)
    }

    @Test func nextPendingExportTrueWhileExportInFlight() {
        let result = CloudSyncMonitor.nextPendingExport(current: false, eventType: .export, isFinished: false, succeeded: false)
        #expect(result == true)
    }

    @Test func nextPendingExportFalseAfterSuccessfulExport() {
        let result = CloudSyncMonitor.nextPendingExport(current: true, eventType: .export, isFinished: true, succeeded: true)
        #expect(result == false)
    }

    @Test func nextPendingExportStaysTrueAfterFailedExport() {
        let result = CloudSyncMonitor.nextPendingExport(current: true, eventType: .export, isFinished: true, succeeded: false)
        #expect(result == true)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/CloudSyncMonitorTests`
Expected: FAIL — build error, `CloudSyncMonitor` does not exist.

- [ ] **Step 3: Write the implementation**

Create `WadeMoney/Persistence/CloudSyncMonitor.swift`:

```swift
import Foundation
import CoreData
import Observation

/// 대시보드 배너와 설정 화면이 구독하는 단일 CloudKit 동기화 상태 소스.
/// 앱 세션 내내 하나의 인스턴스를 `.environment(_:)`로 주입해 공유한다.
@MainActor
@Observable
final class CloudSyncMonitor {
    enum State: Equatable {
        case normal
        case importing
        case unavailable
    }

    private(set) var state: State
    /// 로컬 변경사항이 아직 iCloud로 업로드되지 않았으면 true (삭제 전 백업 확인에 사용).
    private(set) var pendingExport: Bool = false

    init(cloudKitEnabled: Bool, isSignedIntoiCloud: Bool, hasExistingData: Bool) {
        state = CloudSyncMonitor.initialState(
            cloudKitEnabled: cloudKitEnabled,
            isSignedIntoiCloud: isSignedIntoiCloud,
            hasExistingData: hasExistingData
        )
    }

    static func initialState(cloudKitEnabled: Bool, isSignedIntoiCloud: Bool, hasExistingData: Bool) -> State {
        guard cloudKitEnabled, isSignedIntoiCloud else { return .unavailable }
        return hasExistingData ? .normal : .importing
    }

    /// NSPersistentCloudKitContainer.Event는 공개 이니셜라이저가 없어 테스트에서 직접 만들 수 없다.
    /// 그래서 이벤트에서 뽑아낸 원시 값(enum/Bool)만 받는 순수 함수로 분리해 유닛 테스트 가능하게 한다.
    static func nextState(
        current: State,
        eventType: NSPersistentCloudKitContainer.EventType,
        isFinished: Bool,
        succeeded: Bool
    ) -> State {
        guard eventType == .import, isFinished else { return current }
        return succeeded ? .normal : .unavailable
    }

    static func nextPendingExport(
        current: Bool,
        eventType: NSPersistentCloudKitContainer.EventType,
        isFinished: Bool,
        succeeded: Bool
    ) -> Bool {
        guard eventType == .export else { return current }
        return isFinished ? !succeeded : true
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/CloudSyncMonitorTests`
Expected: PASS — all 13 tests green.

- [ ] **Step 5: Commit**

```bash
git add WadeMoney/Persistence/CloudSyncMonitor.swift WadeMoneyTests/CloudSyncMonitorTests.swift
git commit -m "feat(sync): add CloudSyncMonitor state machine"
```

---

### Task 3: Live CloudKit event wiring

**Files:**
- Modify: `WadeMoney/Persistence/CloudSyncMonitor.swift`

**Interfaces:**
- Consumes: `CloudSyncMonitor.nextState`, `CloudSyncMonitor.nextPendingExport` (Task 2).
- Produces: same public surface as Task 2, now with live updates. No new public API.

**Note before starting:** `NSPersistentCloudKitContainer.Event` has no public initializer, so this task's notification-parsing closure cannot be covered by an automated test — verification is a manual, on-device/simulator check (Step 4 below). Do not skip it and do not claim this task complete without running it.

- [ ] **Step 1: Add the observer property and lifecycle**

In `WadeMoney/Persistence/CloudSyncMonitor.swift`, add a stored property right after `pendingExport` and a `deinit`:

```swift
    private(set) var pendingExport: Bool = false
    private var observer: NSObjectProtocol?

    init(cloudKitEnabled: Bool, isSignedIntoiCloud: Bool, hasExistingData: Bool) {
        state = CloudSyncMonitor.initialState(
            cloudKitEnabled: cloudKitEnabled,
            isSignedIntoiCloud: isSignedIntoiCloud,
            hasExistingData: hasExistingData
        )
        if cloudKitEnabled {
            startObserving()
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
```

(This replaces the existing `init` from Task 2 — same body plus the `if cloudKitEnabled { startObserving() }` call, and the `deinit` is new.)

- [ ] **Step 2: Add the observing method**

Append to the bottom of the class, after `nextPendingExport`:

```swift
    private func startObserving() {
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
            let type = event.type
            let isFinished = event.endDate != nil
            let succeeded = event.succeeded
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.state = CloudSyncMonitor.nextState(current: self.state, eventType: type, isFinished: isFinished, succeeded: succeeded)
                self.pendingExport = CloudSyncMonitor.nextPendingExport(current: self.pendingExport, eventType: type, isFinished: isFinished, succeeded: succeeded)
            }
        }
    }
```

- [ ] **Step 3: Build to confirm it compiles under Swift 6 strict concurrency**

Run: `xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: BUILD SUCCEEDED, no Sendability warnings on `CloudSyncMonitor.swift`. If the compiler flags `NSPersistentCloudKitContainer.Event` or `.EventType` crossing an isolation boundary, the fix is to read `event.type`/`event.endDate`/`event.succeeded` synchronously inside the `NotificationCenter` closure (already done above — nothing about `Event` itself is captured by the `Task`) — re-check that only `type`/`isFinished`/`succeeded` (not `event`) are captured by the inner `Task`.

- [ ] **Step 4: Manually verify the notification actually fires (SwiftData + CloudKit is not documented to guarantee this)**

1. Temporarily add a print statement right before the `Task { @MainActor ... }` line in `startObserving()`:
   ```swift
   print("[CloudSyncMonitor] type=\(type) finished=\(isFinished) succeeded=\(succeeded)")
   ```
2. Build and run on a **signed** simulator or device (a development team must be assigned in Xcode — an unsigned build has no App Group entitlement, so `isAppGroupAvailable` is false and this code path never runs at all).
3. Run: `xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`, then launch the app from Xcode (not `xcodebuild test`) so the console is visible.
4. Watch the Xcode console for `[CloudSyncMonitor]` lines during the first ~30 seconds after launch, and again after adding a transaction via the FAB.
5. **If lines appear:** note whether `.import` fires as expected. This confirms the design's core assumption — proceed to Step 5.
6. **If no lines appear after ~60 seconds** with a signed build and an iCloud-signed-in simulator: STOP. Do not silently work around this. Report to the user that `NSPersistentCloudKitContainer.eventChangedNotification` does not appear to fire for this SwiftData + CloudKit configuration, since Tasks 4-6 depend on this assumption and the design needs to be reconsidered before continuing.
7. Remove the temporary `print` statement.

- [ ] **Step 5: Commit**

```bash
git add WadeMoney/Persistence/CloudSyncMonitor.swift
git commit -m "feat(sync): wire CloudSyncMonitor to live CloudKit import/export events"
```

---

### Task 4: `PersistenceController` + `WadeMoneyApp` wiring

**Files:**
- Modify: `WadeMoney/Persistence/PersistenceController.swift:1-54`
- Modify: `WadeMoney/WadeMoneyApp.swift:1-40`
- Create: `WadeMoneyTests/PersistenceControllerTests.swift`

**Interfaces:**
- Consumes: `CloudSyncMonitor.init(cloudKitEnabled:isSignedIntoiCloud:hasExistingData:)` (Task 2/3), `CategorySeeder.reconcileDuplicateCategories` (Task 1).
- Produces: `AppContainerResult` (`struct { let container: ModelContainer; let cloudKitEnabled: Bool }`), `PersistenceController.makeAppContainer() throws -> AppContainerResult` (return type changed from bare `ModelContainer`). `WadeMoneyApp` now also exposes `let syncMonitor: CloudSyncMonitor` and injects it via `.environment(syncMonitor)`.

- [ ] **Step 1: Write the failing test**

Create `WadeMoneyTests/PersistenceControllerTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
@testable import WadeMoney

@MainActor
struct PersistenceControllerTests {
    @Test func makeAppContainerReportsCloudKitDisabledWhenAppGroupUnavailable() throws {
        // 유닛 테스트 실행 환경(서명되지 않은 호스트)에는 App Group이 프로비저닝되지 않으므로
        // makeAppContainer()는 항상 로컬 컨테이너 + cloudKitEnabled: false를 반환해야 한다.
        let result = try PersistenceController.makeAppContainer()
        #expect(result.cloudKitEnabled == false)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/PersistenceControllerTests`
Expected: FAIL — build error, `makeAppContainer()` returns `ModelContainer`, not something with `.cloudKitEnabled`.

- [ ] **Step 3: Change `PersistenceController.makeAppContainer()`'s return type**

Replace `WadeMoney/Persistence/PersistenceController.swift` lines 1-54 entirely:

```swift
import Foundation
import SwiftData

struct AppContainerResult {
    let container: ModelContainer
    let cloudKitEnabled: Bool
}

enum PersistenceController {
    static let sharedSchema = Schema([
        CategoryModel.self,
        TransactionModel.self,
        MonthlyBudgetModel.self,
        AppSettingsModel.self,
    ])

    /// App Group 컨테이너가 실제로 프로비저닝돼 있는지(엔타이틀먼트 유효 여부).
    /// 미서명 시뮬레이터 등에서는 nil → App Group/CloudKit 경로를 시도하면
    /// SwiftData가 잡을 수 없는 fatalError를 낸다. 그래서 먼저 확인한다.
    private static var isAppGroupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppIDs.appGroup) != nil
    }

    /// 프로덕션: App Group 공유 저장소 + CloudKit 개인 DB 동기화.
    /// App Group이 프로비저닝되지 않은 환경(미서명 시뮬레이터 등)에서는
    /// 공유·CloudKit 없이 로컬 온디스크로 기동해 앱이 크래시 없이 뜨게 한다.
    /// (실제 동기화는 유료 Apple Developer 계정 + 프로비저닝된 iCloud 컨테이너 + 실기기 필요.)
    static func makeAppContainer() throws -> AppContainerResult {
        guard isAppGroupAvailable else {
            return AppContainerResult(container: try makeLocalContainer(), cloudKitEnabled: false)
        }
        do {
            let config = ModelConfiguration(
                schema: sharedSchema,
                groupContainer: .identifier(AppIDs.appGroup),
                cloudKitDatabase: .private(AppIDs.iCloudContainer)
            )
            let container = try ModelContainer(for: sharedSchema, configurations: [config])
            return AppContainerResult(container: container, cloudKitEnabled: true)
        } catch {
            // CloudKit init 실패 시에도 App Group 공유 저장소는 유지(위젯이 읽을 수 있게).
            let config = ModelConfiguration(schema: sharedSchema, groupContainer: .identifier(AppIDs.appGroup))
            let container = try ModelContainer(for: sharedSchema, configurations: [config])
            return AppContainerResult(container: container, cloudKitEnabled: false)
        }
    }

    /// 로컬 온디스크 폴백: 그룹·CloudKit 없는 플레인 저장소.
    /// (CloudKit 초기화 실패 시에도, 또는 App Group 미프로비저닝 환경에서도
    /// 데이터가 콜드런치마다 사라지지 않도록.)
    static func makeLocalContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: sharedSchema)
        return try ModelContainer(for: sharedSchema, configurations: [config])
    }

    /// 테스트/프리뷰: 인메모리, CloudKit 없음.
    static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: sharedSchema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: sharedSchema, configurations: [config])
    }
}
```

- [ ] **Step 4: Run to verify the new test passes**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/PersistenceControllerTests`
Expected: PASS.

- [ ] **Step 5: Update `WadeMoneyApp.swift` to consume the new return type and construct `CloudSyncMonitor`**

Replace `WadeMoney/WadeMoneyApp.swift` lines 1-40 entirely:

```swift
import SwiftUI
import SwiftData

@main
struct WadeMoneyApp: App {
    let container: ModelContainer
    let syncMonitor: CloudSyncMonitor

    init() {
        // 테스트 호스트로 실행 중이면 App Group/CloudKit 엔타이틀먼트가 없어
        // makeAppContainer()가 복구 불가능한 fatal error를 낼 수 있으므로 우회한다.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            container = try! PersistenceController.makeInMemoryContainer()
            syncMonitor = CloudSyncMonitor(cloudKitEnabled: false, isSignedIntoiCloud: false, hasExistingData: false)
            return
        }
        let resolved: ModelContainer
        let cloudKitEnabled: Bool
        do {
            let result = try PersistenceController.makeAppContainer()
            resolved = result.container
            cloudKitEnabled = result.cloudKitEnabled
        } catch {
            // CloudKit 초기화 실패 시 온디스크 로컬 저장소로 폴백(데이터가 콜드런치마다 사라지지 않도록).
            do {
                resolved = try PersistenceController.makeLocalContainer()
            } catch {
                // 로컬 저장소마저 실패하면 최후 수단으로 인메모리 폴백(앱은 뜬다).
                resolved = try! PersistenceController.makeInMemoryContainer()
            }
            cloudKitEnabled = false
        }
        container = resolved
        try? CategorySeeder.seedIfNeeded(resolved.mainContext)
        // CloudKit 병합으로 생긴 중복 카테고리를 매 실행 시 결정적으로 합친다(멱등).
        try? CategorySeeder.reconcileDuplicateCategories(resolved.mainContext)
        try? _ = SettingsStore(context: resolved.mainContext).settingsModel()

        let hasExistingData = ((try? resolved.mainContext.fetchCount(FetchDescriptor<TransactionModel>())) ?? 0) > 0
        syncMonitor = CloudSyncMonitor(
            cloudKitEnabled: cloudKitEnabled,
            isSignedIntoiCloud: FileManager.default.ubiquityIdentityToken != nil,
            hasExistingData: hasExistingData
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
        .environment(syncMonitor)
    }
}
```

- [ ] **Step 6: Build the whole app target to confirm everything still compiles**

Run: `xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Run the full unit test suite to confirm no regressions**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests`
Expected: PASS — all existing + new tests green.

- [ ] **Step 8: Commit**

```bash
git add WadeMoney/Persistence/PersistenceController.swift WadeMoney/WadeMoneyApp.swift WadeMoneyTests/PersistenceControllerTests.swift
git commit -m "feat(sync): wire CloudSyncMonitor into app startup"
```

---

### Task 5: Dashboard sync-status banner

**Files:**
- Create: `WadeMoney/DesignSystem/AnimatedDots.swift`
- Modify: `WadeMoney/Screens/Dashboard/DashboardComponents.swift` (append at end of file)
- Modify: `WadeMoney/Screens/Dashboard/DashboardScreen.swift:1-35`

**Interfaces:**
- Consumes: `CloudSyncMonitor.State` (Task 2), injected via `.environment(CloudSyncMonitor.self)` (Task 4).
- Produces: `SyncStatusBanner: View` (`init(state: CloudSyncMonitor.State)`), `AnimatedDots: View` (no params).

This task has no automated test — it is pure SwiftUI rendering. Verification is a manual simulator screenshot pass (Step 4).

- [ ] **Step 1: Create the reusable dot-cycling indicator**

Create `WadeMoney/DesignSystem/AnimatedDots.swift`:

```swift
import SwiftUI

/// "가져오는 중" 같은 진행 문구 뒤에 붙어 점 개수가 0~3개를 순환하며
/// 실제로 진행되고 있음을 시각적으로 표현한다. 진행률 수치가 아니라 반복 애니메이션일 뿐이다.
struct AnimatedDots: View {
    @State private var count = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(String(repeating: ".", count: count))
            .frame(width: 18, alignment: .leading)
            .onReceive(timer) { _ in
                count = (count + 1) % 4
            }
    }
}
```

- [ ] **Step 2: Add `SyncStatusBanner` to `DashboardComponents.swift`**

Append to the end of `WadeMoney/Screens/Dashboard/DashboardComponents.swift`:

```swift
struct SyncStatusBanner: View {
    @Environment(\.colorScheme) private var scheme
    let state: CloudSyncMonitor.State

    var body: some View {
        switch state {
        case .normal:
            EmptyView()
        case .importing:
            content(icon: "cloud_sync", tint: WadeColors.ink2(scheme)) {
                HStack(spacing: 0) {
                    Text("iCloud에서 가져오는 중").font(WadeFont.pretendard(12.5, weight: .semibold))
                    AnimatedDots().font(WadeFont.pretendard(12.5, weight: .semibold))
                }
            }
        case .unavailable:
            content(icon: "cloud_off", tint: WadeColors.ink3(scheme)) {
                Text("iCloud 동기화 꺼짐").font(WadeFont.pretendard(12.5, weight: .semibold))
            }
        }
    }

    @ViewBuilder
    private func content<Label: View>(icon: String, tint: Color, @ViewBuilder label: () -> Label) -> some View {
        HStack(spacing: 6) {
            Icon(icon, size: 14, filled: false).foregroundStyle(tint)
            label().foregroundStyle(tint)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WadeColors.card2(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.smallTile, style: .continuous))
    }
}
```

- [ ] **Step 3: Place the banner in `DashboardScreen`**

In `WadeMoney/Screens/Dashboard/DashboardScreen.swift`, add the environment property alongside the existing `@State` properties (after line 6 `@Environment(\.modelContext) private var modelContext`):

```swift
    @Environment(CloudSyncMonitor.self) private var syncMonitor
```

Then insert the banner right after the header `HStack`'s closing `.frame(maxWidth: .infinity)` (currently line 35) and before `if let vm = viewModel, let d = vm.display {`:

```swift
                    .frame(maxWidth: .infinity)

                    SyncStatusBanner(state: syncMonitor.state)

                    if let vm = viewModel, let d = vm.display {
```

- [ ] **Step 4: Build, then manually verify all 3 states render correctly**

Run: `xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: BUILD SUCCEEDED.

To see all 3 states without a real CloudKit account, temporarily hardcode the `syncMonitor` construction in `WadeMoneyApp.swift` (the production branch, not the `XCTestConfigurationFilePath` branch) to force each state one at a time, e.g.:

```swift
syncMonitor = CloudSyncMonitor(cloudKitEnabled: true, isSignedIntoiCloud: true, hasExistingData: false) // forces .importing
```

For each of the 3 states, run the app in Simulator and take a screenshot (reuse this session's established pattern: add a temporary screenshot XCUITest method to `WadeMoneyUITests/CoreFlowUITests.swift`, run `xcodebuild clean -scheme WadeMoneyUITests` then `xcodebuild test -scheme WadeMoneyUITests -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyUITests/CoreFlowUITests/<methodName>`, export via `xcrun xcresulttool export attachments`, Read the PNG, then fully revert the temporary test method). Confirm:
- `.normal` → no banner, no extra space above the period segment.
- `.importing` → banner visible with cycling dots, icon `cloud_sync`.
- `.unavailable` → banner visible, icon `cloud_off`, text "iCloud 동기화 꺼짐".

Revert the temporary hardcoded `syncMonitor` override in `WadeMoneyApp.swift` back to the real logic from Task 4 before committing.

- [ ] **Step 5: Commit**

```bash
git add WadeMoney/DesignSystem/AnimatedDots.swift WadeMoney/Screens/Dashboard/DashboardComponents.swift WadeMoney/Screens/Dashboard/DashboardScreen.swift
git commit -m "feat(dashboard): show CloudKit sync status banner"
```

---

### Task 6: Settings sync-status row + backup-check row

**Files:**
- Modify: `WadeMoney/Screens/Settings/SettingsScreen.swift`

**Interfaces:**
- Consumes: `CloudSyncMonitor.State`, `CloudSyncMonitor.pendingExport` (Task 2), injected via `.environment(CloudSyncMonitor.self)` (Task 4), `AnimatedDots` (Task 5).

This task has no automated test — it is pure SwiftUI rendering plus a toast side effect already covered by the existing `showSettingsToast` mechanism. Verification is a manual simulator screenshot pass (Step 4), reusing the same 3-state override technique as Task 5.

- [ ] **Step 1: Add the environment property**

In `WadeMoney/Screens/Settings/SettingsScreen.swift`, add alongside the existing `@Environment`/`@State` properties (after line 9 `@Environment(\.modelContext) private var modelContext`):

```swift
    @Environment(CloudSyncMonitor.self) private var syncMonitor
```

- [ ] **Step 2: Replace the hardcoded sync row and add the backup-check row**

Replace lines 58-62:

```swift
                            section("동기화 · 데이터") {
                                row(icon: "cloud_done", tint: WadeColors.good(scheme), label: "iCloud 동기화",
                                    subtitle: "iCloud에 안전하게 보관돼요", subtitleColor: WadeColors.good(scheme), trailing: nil, action: nil)
                                row(icon: "ios_share", tint: WadeColors.ink2(scheme), label: "CSV 내보내기", trailing: nil) { exportCSV() }
                            }
```

with:

```swift
                            section("동기화 · 데이터") {
                                syncStatusRow()
                                backupCheckRow()
                                row(icon: "ios_share", tint: WadeColors.ink2(scheme), label: "CSV 내보내기", trailing: nil) { exportCSV() }
                            }
```

- [ ] **Step 3: Add the three new helper methods**

Add after `appearanceRow(_:)` (after line 284, before `aiToggleRow(_:)`):

```swift
    private func syncStatusRow() -> some View {
        switch syncMonitor.state {
        case .normal:
            return row(icon: "cloud_done", tint: WadeColors.good(scheme), label: "iCloud 동기화",
                       subtitle: "모든 기기에서 최신 상태로 유지돼요", subtitleColor: WadeColors.good(scheme), trailing: nil, action: nil)
        case .importing:
            return row(icon: "cloud_sync", tint: WadeColors.ink2(scheme), label: "iCloud 동기화",
                       subtitle: "iCloud에서 가져오는 중", subtitleColor: WadeColors.ink2(scheme), trailing: nil, action: nil)
        case .unavailable:
            return row(icon: "cloud_off", tint: WadeColors.ink3(scheme), label: "iCloud 동기화",
                       subtitle: "iCloud 로그인 상태를 확인해주세요", subtitleColor: WadeColors.ink3(scheme), trailing: nil, action: nil)
        }
    }

    private func backupCheckRow() -> some View {
        let unavailable = syncMonitor.state == .unavailable
        return row(
            icon: "cloud_upload",
            tint: unavailable ? WadeColors.ink3(scheme) : WadeColors.ink2(scheme),
            label: "iCloud 백업 상태 확인",
            trailing: unavailable ? "확인 불가" : nil,
            action: unavailable ? nil : { checkBackupStatus() }
        )
    }

    private func checkBackupStatus() {
        if syncMonitor.pendingExport {
            showSettingsToast("아직 업로드 중이에요. 네트워크 연결을 확인하고 잠시 후 다시 확인해주세요.")
        } else {
            showSettingsToast("모든 데이터가 iCloud에 안전하게 저장됐어요. 지금 앱을 삭제해도 괜찮아요.")
        }
    }
```

- [ ] **Step 4: Build, then manually verify all 3 states + the backup-check toast**

Run: `xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: BUILD SUCCEEDED.

Using the same temporary `syncMonitor` override technique from Task 5 Step 4, verify on the Settings screen:
- `.normal` → green `cloud_done`, "모든 기기에서 최신 상태로 유지돼요"; backup-check row tappable.
- `.importing` → `cloud_sync`, "iCloud에서 가져오는 중" with cycling dots; backup-check row tappable.
- `.unavailable` → `cloud_off`, "iCloud 로그인 상태를 확인해주세요"; backup-check row shows "확인 불가" and is not tappable.
- Tap "iCloud 백업 상태 확인" in `.normal`/`.importing` states and confirm the toast appears with the expected message (temporarily force `pendingExport` in the `CloudSyncMonitor` init call to see both toast variants, then revert).

Revert all temporary overrides in `WadeMoneyApp.swift` before committing.

- [ ] **Step 5: Commit**

```bash
git add WadeMoney/Screens/Settings/SettingsScreen.swift
git commit -m "feat(settings): show real CloudKit sync state and backup-check action"
```

---

## Final Verification

- [ ] Run the full unit test suite once more: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests`. Expected: all green.
- [ ] Run the existing UI test suite to confirm no regression in the core flow: `xcodebuild test -scheme WadeMoneyUITests -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyUITests/CoreFlowUITests`. Expected: both existing tests pass (they don't touch sync UI, but they do exercise `DashboardScreen`/`SettingsScreen`, which now require `CloudSyncMonitor` in the environment — this is the regression check that the environment injection didn't break app launch).
- [ ] Confirm `git diff` against `main` touches no files under `docs/design/app-design-specification-analysis/` (unrelated pre-existing local changes noted in git status at session start).
