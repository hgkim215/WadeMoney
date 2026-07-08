# Onboarding Tour Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a 4-page first-launch onboarding tour (intro → quick-add → AI insight → notification permission) that shows automatically only to genuinely new installs, and can be re-opened anytime from Settings.

**Architecture:** A new `OnboardingView` (SwiftUI `TabView(.page)`, 4 tagged pages) is inserted into `RootView`'s existing splash → update-check sequencing, gated by a pure `OnboardingGate.shouldShow(didCompleteOnboarding:hasExistingData:)` helper. The last page reuses the already-shipped `SettingsViewModel.setDailyReminderEnabled(_:)` to request notification permission. Completion is persisted via a new `AppSettingsModel.didCompleteOnboarding` field (CloudKit-synced, same pattern as `didSeedDefaultCategories`). The same `OnboardingView` is reused, unmodified, as a Settings sheet for on-demand re-viewing.

**Tech Stack:** SwiftUI (`TabView(.page)`), SwiftData (`AppSettingsModel`), the existing `SettingsStore`/`SettingsViewModel`/`NotificationScheduling` infrastructure from the daily-reminder feature.

## Global Constraints

- Show automatically only when `!didCompleteOnboarding && !hasExistingData` — existing users (any account with transaction data) never see it automatically, even though the new field defaults to `false` for them too.
- 4 pages, fixed copy (no A/B variants):
  1. 소개 — "WadeMoney에 오신 걸 환영해요" / "가볍게 기록하는 하루 지출, 온디바이스 가계부예요" (마스코트)
  2. 빠른입력 — "몇 번의 탭이면 끝나요" / "가운데 + 버튼으로 금액·카테고리·메모만 입력하면 저장 끝" (아이콘 `add`)
  3. AI인사이트 — "AI가 지출을 정리해드려요" / "카테고리 비중, 지출 추세를 온디바이스 AI가 자동으로 분석해요" (아이콘 `auto_awesome`)
  4. 알림권한 — "매일 잊지 않게 알려드릴게요" / "밤 10시(설정에서 변경 가능)에 오늘 지출을 기록했는지 알려드려요" (아이콘 `notifications`), 버튼 "알림 받기"/"나중에 하기"
- Pages 1–3: top-trailing "건너뛰기" button jumps straight to page 4; bottom "다음" button advances one page; swipe also works.
- Page 4 has no "건너뛰기"/"다음" — only "알림 받기" (calls `SettingsViewModel.setDailyReminderEnabled(true)`) and "나중에 하기" (no scheduler call). Both persist `didCompleteOnboarding = true` and dismiss.
- Settings → 도움말 gets a "가이드 다시 보기" row that presents the same `OnboardingView` as a sheet, independent of the completion flag.
- Test simulator: `iPhone 17e`. Direct commits to `main` (established this-session convention). Exclude `docs/design/app-design-specification-analysis/` from any git staging.

---

### Task 1: `AppSettingsModel` + `SettingsStore` — completion flag

**Files:**
- Modify: `WadeMoney/Models/AppSettingsModel.swift`
- Modify: `WadeMoney/Stores/SettingsStore.swift`
- Test: `WadeMoneyTests/SettingsStoreTests.swift`

**Interfaces:**
- Produces: `AppSettingsModel.didCompleteOnboarding: Bool` (default `false`), `SettingsStore.setDidCompleteOnboarding(_ completed: Bool) throws`.

- [ ] **Step 1: Write the failing test**

Add to `WadeMoneyTests/SettingsStoreTests.swift`, right after `appearanceDefaultsToSystemAndPersists`:

```swift
    @Test func onboardingDefaultsToIncompleteAndPersistsWhenSet() throws {
        let (s, container) = try store()
        #expect(try s.settingsModel().didCompleteOnboarding == false)
        try s.setDidCompleteOnboarding(true)
        #expect(try s.settingsModel().didCompleteOnboarding == true)
        _ = container
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodegen generate && xcodebuild clean -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' && xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/SettingsStoreTests`
Expected: FAIL — "value of type 'AppSettingsModel' has no member 'didCompleteOnboarding'" / "value of type 'SettingsStore' has no member 'setDidCompleteOnboarding'"

- [ ] **Step 3: Implement**

In `WadeMoney/Models/AppSettingsModel.swift`, add the field and init parameter (full replacement):

```swift
import Foundation
import SwiftData

@Model
final class AppSettingsModel {
    var id: UUID = UUID()
    var monthStartDay: Int = 1
    var aiEnabled: Bool = true
    var didSeedDefaultCategories: Bool = false
    /// AppAppearance.rawValue (0=시스템, 1=라이트, 2=다크).
    var appearanceRaw: Int = 0
    var dailyReminderEnabled: Bool = false
    var dailyReminderHour: Int = 22
    var dailyReminderMinute: Int = 0
    var didCompleteOnboarding: Bool = false

    init(
        id: UUID = UUID(),
        monthStartDay: Int = 1,
        aiEnabled: Bool = true,
        didSeedDefaultCategories: Bool = false,
        appearanceRaw: Int = 0,
        dailyReminderEnabled: Bool = false,
        dailyReminderHour: Int = 22,
        dailyReminderMinute: Int = 0,
        didCompleteOnboarding: Bool = false
    ) {
        self.id = id
        self.monthStartDay = monthStartDay
        self.aiEnabled = aiEnabled
        self.didSeedDefaultCategories = didSeedDefaultCategories
        self.appearanceRaw = appearanceRaw
        self.dailyReminderEnabled = dailyReminderEnabled
        self.dailyReminderHour = dailyReminderHour
        self.dailyReminderMinute = dailyReminderMinute
        self.didCompleteOnboarding = didCompleteOnboarding
    }
}
```

In `WadeMoney/Stores/SettingsStore.swift`, add after `setDailyReminder(enabled:hour:minute:)`:

```swift
    func setDidCompleteOnboarding(_ completed: Bool) throws {
        let model = try settingsModel()
        model.didCompleteOnboarding = completed
        try context.save()
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodegen generate && xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/SettingsStoreTests`
Expected: PASS (all `SettingsStoreTests` cases, including the new one)

- [ ] **Step 5: Commit**

```bash
git add WadeMoney/Models/AppSettingsModel.swift WadeMoney/Stores/SettingsStore.swift WadeMoneyTests/SettingsStoreTests.swift
git commit -m "feat(settings): add didCompleteOnboarding flag to AppSettingsModel + SettingsStore"
```

---

### Task 2: `OnboardingGate` — pure gating logic

**Files:**
- Create: `WadeMoney/Screens/Onboarding/OnboardingGate.swift`
- Test: `WadeMoneyTests/OnboardingGateTests.swift`

**Interfaces:**
- Produces: `OnboardingGate.shouldShow(didCompleteOnboarding: Bool, hasExistingData: Bool) -> Bool`.
- Consumed by: Task 5 (`RootView`).

This is deliberately a free function with no SwiftData/SwiftUI dependency, so the "existing users never see it automatically" rule is covered by a fast, deterministic unit test rather than relying on fragile fresh-install UI automation (this codebase has no store-reset test infrastructure — see Task 6 for how the interactive-mechanics UI test sidesteps that gap via the Settings re-entry point instead).

- [ ] **Step 1: Write the failing test**

Create `WadeMoneyTests/OnboardingGateTests.swift`:

```swift
import Testing
@testable import WadeMoney

struct OnboardingGateTests {
    @Test func showsForFreshInstallWithNoCompletionAndNoData() {
        #expect(OnboardingGate.shouldShow(didCompleteOnboarding: false, hasExistingData: false) == true)
    }

    @Test func hidesWhenAlreadyCompleted() {
        #expect(OnboardingGate.shouldShow(didCompleteOnboarding: true, hasExistingData: false) == false)
    }

    @Test func hidesForExistingUsersEvenIfFlagDefaultsFalse() {
        #expect(OnboardingGate.shouldShow(didCompleteOnboarding: false, hasExistingData: true) == false)
    }

    @Test func hidesWhenBothCompletedAndHasData() {
        #expect(OnboardingGate.shouldShow(didCompleteOnboarding: true, hasExistingData: true) == false)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodegen generate && xcodebuild clean -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' && xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/OnboardingGateTests`
Expected: FAIL — "cannot find 'OnboardingGate' in scope"

- [ ] **Step 3: Implement**

Create `WadeMoney/Screens/Onboarding/OnboardingGate.swift`:

```swift
import Foundation

/// 온보딩 자동 표시 여부를 결정하는 순수 함수. 신규 설치(기존 거래 데이터 없음)이고
/// 아직 완료하지 않은 경우에만 자동으로 보여준다 — 이미 데이터가 있는 기존 사용자는
/// didCompleteOnboarding 필드가 새로 추가되어 기본값 false를 갖더라도 제외된다.
enum OnboardingGate {
    static func shouldShow(didCompleteOnboarding: Bool, hasExistingData: Bool) -> Bool {
        !didCompleteOnboarding && !hasExistingData
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodegen generate && xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/OnboardingGateTests`
Expected: PASS (all 4 cases)

- [ ] **Step 5: Commit**

```bash
git add WadeMoney/Screens/Onboarding/OnboardingGate.swift WadeMoneyTests/OnboardingGateTests.swift
git commit -m "feat(onboarding): add OnboardingGate pure gating logic"
```

---

### Task 3: Page view components

**Files:**
- Create: `WadeMoney/Screens/Onboarding/OnboardingPage.swift`
- Create: `WadeMoney/Screens/Onboarding/OnboardingReminderPage.swift`

**Interfaces:**
- Produces: `OnboardingPage(icon: String?, title: String, message: String)` — `icon == nil` renders the mascot (`MascotView(state: .finalPose)`) instead of an icon badge.
- Produces: `OnboardingReminderPage(onEnable: () -> Void, onLater: () -> Void)`.
- Consumed by: Task 4 (`OnboardingView`).

No dedicated unit tests for these — matches this codebase's existing convention for presentational sheet views (`MonthStartDaySheet`, `NotificationTimeSheet` have none either); correctness is verified by successful compilation here and exercised end-to-end by the UI test in Task 6.

- [ ] **Step 1: Create `WadeMoney/Screens/Onboarding/OnboardingPage.swift`**

```swift
import SwiftUI

/// 온보딩 1~3페이지가 공유하는 레이아웃: 아이콘(또는 마스코트) + 제목 + 설명.
/// icon이 nil이면 스플래시와 동일한 마스코트를 대신 보여준다(첫 페이지 전용).
struct OnboardingPage: View {
    @Environment(\.colorScheme) private var scheme
    let icon: String?
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            if let icon {
                Icon(icon, size: 44)
                    .foregroundStyle(WadeColors.onPrimary(scheme))
                    .frame(width: 96, height: 96)
                    .background(WadeColors.primary(scheme), in: Circle())
            } else {
                MascotView(state: .finalPose)
            }
            VStack(spacing: 10) {
                Text(title)
                    .font(WadeFont.pretendard(24, weight: .heavy))
                    .foregroundStyle(WadeColors.ink(scheme))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(WadeFont.pretendard(15))
                    .foregroundStyle(WadeColors.ink2(scheme))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 2: Create `WadeMoney/Screens/Onboarding/OnboardingReminderPage.swift`**

```swift
import SwiftUI

/// 온보딩 마지막(4번째) 페이지: 알림 권한 요청. 실제 스케줄링 호출은 OnboardingView가
/// SettingsViewModel.setDailyReminderEnabled를 통해 수행하고, 이 뷰는 두 액션만 노출한다.
struct OnboardingReminderPage: View {
    @Environment(\.colorScheme) private var scheme
    let onEnable: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Icon("notifications", size: 44)
                .foregroundStyle(WadeColors.onPrimary(scheme))
                .frame(width: 96, height: 96)
                .background(WadeColors.primary(scheme), in: Circle())
            VStack(spacing: 10) {
                Text("매일 잊지 않게 알려드릴게요")
                    .font(WadeFont.pretendard(24, weight: .heavy))
                    .foregroundStyle(WadeColors.ink(scheme))
                    .multilineTextAlignment(.center)
                Text("밤 10시(설정에서 변경 가능)에 오늘 지출을 기록했는지 알려드려요")
                    .font(WadeFont.pretendard(15))
                    .foregroundStyle(WadeColors.ink2(scheme))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 12) {
                Button(action: onEnable) {
                    Text("알림 받기")
                        .font(WadeFont.pretendard(17, weight: .heavy))
                        .foregroundStyle(WadeColors.onPrimary(scheme))
                        .frame(maxWidth: .infinity).padding(17)
                        .background(WadeColors.primary(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.button, style: .continuous))
                }.buttonStyle(.plain)

                Button(action: onLater) {
                    Text("나중에 하기")
                        .font(WadeFont.pretendard(15, weight: .semibold))
                        .foregroundStyle(WadeColors.ink2(scheme))
                        .frame(maxWidth: .infinity).padding(12)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, WadeSpacing.screenH)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 3: Regenerate project and build**

Run: `xcodegen generate && xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: `** BUILD SUCCEEDED **` (nothing references these files yet, so this only proves they compile standalone)

- [ ] **Step 4: Commit**

```bash
git add WadeMoney/Screens/Onboarding/OnboardingPage.swift WadeMoney/Screens/Onboarding/OnboardingReminderPage.swift
git commit -m "feat(onboarding): add OnboardingPage and OnboardingReminderPage views"
```

---

### Task 4: `OnboardingView` container

**Files:**
- Create: `WadeMoney/Screens/Onboarding/OnboardingView.swift`

**Interfaces:**
- Consumes: `OnboardingPage`, `OnboardingReminderPage` (Task 3); `SettingsStore.setDidCompleteOnboarding(_:)` (Task 1); `SettingsViewModel(settingsStore:categoryStore:now:calendar:)` and `SettingsViewModel.setDailyReminderEnabled(_:) async -> Bool` (already shipped, from `WadeMoney/Screens/Settings/SettingsViewModel.swift`); `CategoryStore(context:)` (already shipped).
- Produces: `OnboardingView(onFinished: () -> Void)` — a full-screen, opaque-background view. Consumed by Task 5 (`RootView`) and Task 6 (`SettingsScreen`).

- [ ] **Step 1: Create `WadeMoney/Screens/Onboarding/OnboardingView.swift`**

```swift
import SwiftUI

/// 앱 첫 실행 시(신규 설치 + 기존 데이터 없음) 자동으로 뜨는 4페이지 온보딩 투어.
/// 설정 화면의 "가이드 다시 보기"에서도 동일한 뷰를 시트로 재사용한다 — 완료 플래그를
/// 다시 true로 저장해도 멱등이라 재진입 경로를 따로 분기할 필요가 없다.
struct OnboardingView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @State private var selection = 0
    @State private var settingsViewModel: SettingsViewModel?
    let onFinished: () -> Void

    private let infoPages: [(icon: String?, title: String, message: String)] = [
        (nil, "WadeMoney에 오신 걸 환영해요", "가볍게 기록하는 하루 지출, 온디바이스 가계부예요"),
        ("add", "몇 번의 탭이면 끝나요", "가운데 + 버튼으로 금액·카테고리·메모만 입력하면 저장 끝"),
        ("auto_awesome", "AI가 지출을 정리해드려요", "카테고리 비중, 지출 추세를 온디바이스 AI가 자동으로 분석해요")
    ]

    private var reminderPageIndex: Int { infoPages.count }

    var body: some View {
        ZStack {
            WadeColors.bg(scheme).ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    TabView(selection: $selection) {
                        ForEach(Array(infoPages.enumerated()), id: \.offset) { index, page in
                            OnboardingPage(icon: page.icon, title: page.title, message: page.message)
                                .tag(index)
                        }
                        OnboardingReminderPage(onEnable: enableReminder, onLater: complete)
                            .tag(reminderPageIndex)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    if selection < reminderPageIndex {
                        Button("건너뛰기") { selection = reminderPageIndex }
                            .font(WadeFont.pretendard(14, weight: .semibold))
                            .foregroundStyle(WadeColors.ink3(scheme))
                            .padding(.horizontal, WadeSpacing.screenH)
                            .padding(.top, 18)
                    }
                }

                dotIndicator
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                if selection < reminderPageIndex {
                    Button {
                        selection += 1
                    } label: {
                        Text("다음")
                            .font(WadeFont.pretendard(17, weight: .heavy))
                            .foregroundStyle(WadeColors.onPrimary(scheme))
                            .frame(maxWidth: .infinity).padding(17)
                            .background(WadeColors.primary(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.button, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, WadeSpacing.screenH)
                    .padding(.bottom, 28)
                }
            }
        }
        .onAppear {
            if settingsViewModel == nil {
                let ctx = modelContext
                let vm = SettingsViewModel(settingsStore: SettingsStore(context: ctx),
                                           categoryStore: CategoryStore(context: ctx),
                                           now: Date(), calendar: .current)
                vm.load()
                settingsViewModel = vm
            }
        }
    }

    private var dotIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0...reminderPageIndex, id: \.self) { index in
                Circle()
                    .fill(index == selection ? WadeColors.primary(scheme) : WadeColors.line(scheme))
                    .frame(width: 7, height: 7)
            }
        }
    }

    private func enableReminder() {
        Task {
            await settingsViewModel?.setDailyReminderEnabled(true)
            complete()
        }
    }

    private func complete() {
        try? SettingsStore(context: modelContext).setDidCompleteOnboarding(true)
        onFinished()
    }
}

#Preview {
    OnboardingView(onFinished: {})
}
```

- [ ] **Step 2: Regenerate project and build**

Run: `xcodegen generate && xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add WadeMoney/Screens/Onboarding/OnboardingView.swift
git commit -m "feat(onboarding): add OnboardingView TabView(.page) container"
```

---

### Task 5: Wire into `RootView` / `WadeMoneyApp`

**Files:**
- Modify: `WadeMoney/WadeMoneyApp.swift`
- Modify: `WadeMoney/RootView.swift`

**Interfaces:**
- Consumes: `OnboardingGate.shouldShow(didCompleteOnboarding:hasExistingData:)` (Task 2), `OnboardingView(onFinished:)` (Task 4), `AppSettingsModel.didCompleteOnboarding` (Task 1).

- [ ] **Step 1: Thread `hasExistingData` from `WadeMoneyApp` into `RootView`**

Full replacement of `WadeMoney/WadeMoneyApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct WadeMoneyApp: App {
    let container: ModelContainer
    let syncMonitor: CloudSyncMonitor
    let hasExistingData: Bool

    init() {
        // 테스트 호스트로 실행 중이면 App Group/CloudKit 엔타이틀먼트가 없어
        // makeAppContainer()가 복구 불가능한 fatal error를 낼 수 있으므로 우회한다.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            container = try! PersistenceController.makeInMemoryContainer()
            syncMonitor = CloudSyncMonitor(cloudKitEnabled: false, isSignedIntoiCloud: false, hasExistingData: false)
            hasExistingData = false
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

        let existingData = ((try? resolved.mainContext.fetchCount(FetchDescriptor<TransactionModel>())) ?? 0) > 0
        hasExistingData = existingData
        syncMonitor = CloudSyncMonitor(
            cloudKitEnabled: cloudKitEnabled,
            isSignedIntoiCloud: FileManager.default.ubiquityIdentityToken != nil,
            hasExistingData: existingData
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(hasExistingData: hasExistingData)
        }
        .modelContainer(container)
        .environment(syncMonitor)
    }
}
```

- [ ] **Step 2: Add onboarding state and sequencing to `RootView`**

Full replacement of `WadeMoney/RootView.swift`:

```swift
import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var settingsModels: [AppSettingsModel]
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = SplashVisibility.shouldShowOnLaunch()
    @State private var showOnboarding = false
    @State private var pendingUpdate: UpdateInfo?
    let hasExistingData: Bool

    private let updateChecker = UpdateChecker()

    /// 여러 기기의 CloudKit 병합으로 설정 행이 잠깐 중복될 수 있다 — SettingsStore와 동일하게
    /// id 최솟값 행을 결정적으로 채택한다(둘 다 같은 규칙이어야 기기 간 동일하게 보인다).
    private var appearance: AppAppearance {
        let winner = settingsModels.min { $0.id < $1.id }
        return AppAppearance(rawValue: winner?.appearanceRaw ?? 0) ?? .system
    }

    private var didCompleteOnboarding: Bool {
        settingsModels.min { $0.id < $1.id }?.didCompleteOnboarding ?? false
    }

    var body: some View {
        ZStack {
            RootTabView()

            if let pendingUpdate, !showSplash, !showOnboarding {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .transition(.opacity)

                UpdateAvailablePopup(
                    version: pendingUpdate.version,
                    onLater: { self.pendingUpdate = nil },
                    onUpdate: {
                        let url = pendingUpdate.storeURL
                        self.pendingUpdate = nil
                        openURL(url)
                    }
                )
                .padding(.horizontal, WadeSpacing.screenH)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
                .zIndex(1)
            }

            if showOnboarding {
                OnboardingView(onFinished: {
                    showOnboarding = false
                    Task { await checkForUpdateAfterSplash() }
                })
                .zIndex(2)
            }

            if showSplash {
                SplashScreen(onFinished: {
                    showSplash = false
                    if OnboardingGate.shouldShow(didCompleteOnboarding: didCompleteOnboarding, hasExistingData: hasExistingData) {
                        showOnboarding = true
                    } else {
                        Task { await checkForUpdateAfterSplash() }
                    }
                })
                .zIndex(3)
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .task {
            guard !showSplash, !showOnboarding else { return }
            await checkForUpdateAfterSplash()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, !showSplash, !showOnboarding else { return }
            Task { await checkForUpdateAfterSplash() }
        }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .debugShowUpdatePrompt)) { _ in
            showSplash = false
            showOnboarding = false
            pendingUpdate = DebugUpdatePrompt.updateInfo
        }
        #endif
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: pendingUpdate)
    }

    @MainActor
    private func checkForUpdateAfterSplash() async {
        guard pendingUpdate == nil else { return }
        pendingUpdate = await updateChecker.check()
    }
}

#Preview {
    RootView(hasExistingData: false)
}
```

Note on why `showOnboarding` isn't computed eagerly in the `@State` initializer the way `showSplash` is: `didCompleteOnboarding` comes from `@Query`, which isn't populated yet at `RootView` init time (before the view enters the hierarchy). Evaluating the gate inside `SplashScreen`'s `onFinished` closure — which only fires after the ~1.86s splash animation completes — is functionally equivalent (the user never sees anything before this decision is made) and is the earliest point `@Query` data is reliably available.

- [ ] **Step 3: Regenerate project and build**

Run: `xcodegen generate && xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Run full unit suite to confirm no regressions**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests`
Expected: all tests pass (existing count plus the new ones from Tasks 1–2)

- [ ] **Step 5: Commit**

```bash
git add WadeMoney/WadeMoneyApp.swift WadeMoney/RootView.swift
git commit -m "feat(onboarding): wire OnboardingView into RootView's splash sequencing"
```

---

### Task 6: Settings re-entry + UI test

**Files:**
- Modify: `WadeMoney/Screens/Settings/SettingsScreen.swift`
- Modify: `WadeMoneyUITests/CoreFlowUITests.swift`

**Interfaces:**
- Consumes: `OnboardingView(onFinished:)` (Task 4).

- [ ] **Step 1: Add the sheet case**

In `WadeMoney/Screens/Settings/SettingsScreen.swift`, modify the `SettingsSheet` enum:

```swift
    private enum SettingsSheet: Identifiable {
        case budget
        case monthStartDay
        case notificationTime
        case onboardingGuide
        case share(URL)
        case feedbackMail

        var id: String {
            switch self {
            case .budget: return "budget"
            case .monthStartDay: return "monthStartDay"
            case .notificationTime: return "notificationTime"
            case .onboardingGuide: return "onboardingGuide"
            case .share(let url): return "share-\(url.absoluteString)"
            case .feedbackMail: return "feedbackMail"
            }
        }
    }
```

- [ ] **Step 2: Add the row**

In the `section("도움말")` block, add a row right after the "앱 개선 의견 보내기" row (before the `#if DEBUG` block):

```swift
                                row(
                                    icon: "explore",
                                    tint: WadeColors.ink2(scheme),
                                    label: "가이드 다시 보기",
                                    trailing: nil
                                ) {
                                    presentedSheet = .onboardingGuide
                                }
```

- [ ] **Step 3: Add the sheet content case**

In `sheetContent(_:)`, add before `case .share(let url):`:

```swift
        case .onboardingGuide:
            OnboardingView(onFinished: { presentedSheet = nil })
```

- [ ] **Step 4: Regenerate project and build**

Run: `xcodegen generate && xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Add the UI test**

Add to `WadeMoneyUITests/CoreFlowUITests.swift`, after `testSwipeBackWorksOnCategoryBreakdownAndDetailScreens`:

```swift
    func testOnboardingGuideReplayFromSettingsSkipAndDismiss() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["한눈에"].waitForExistence(timeout: 15))
        button(containing: "설정", in: app).tap()
        button(containing: "가이드 다시 보기", in: app).tap()

        XCTAssertTrue(app.staticTexts["WadeMoney에 오신 걸 환영해요"].waitForExistence(timeout: 5), "온보딩 첫 페이지가 뜨지 않음")

        button(containing: "건너뛰기", in: app).tap()
        XCTAssertTrue(app.staticTexts["매일 잊지 않게 알려드릴게요"].waitForExistence(timeout: 3), "건너뛰기가 알림 페이지로 이동하지 않음")

        button(containing: "나중에 하기", in: app).tap()
        let monthStartRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "월 시작일")).firstMatch
        XCTAssertTrue(monthStartRow.waitForExistence(timeout: 3), "온보딩 종료 후 설정 화면으로 돌아오지 않음")
    }
```

This test uses the Settings re-entry path (not the automatic first-launch path) because it's the only deterministic entry point regardless of what data prior tests in the suite have already created — `OnboardingGate`'s "existing users are excluded" behavior is already covered deterministically by the `OnboardingGateTests` unit tests from Task 2.

- [ ] **Step 6: Run the UI test**

Run: `xcodegen generate && xcodebuild clean -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' && xcodebuild test -scheme WadeMoneyUITests -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyUITests/CoreFlowUITests/testOnboardingGuideReplayFromSettingsSkipAndDismiss`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add WadeMoney/Screens/Settings/SettingsScreen.swift WadeMoneyUITests/CoreFlowUITests.swift
git commit -m "feat(settings): add 가이드 다시 보기 row to replay the onboarding tour"
```

---

### Task 7: Final verification

- [ ] **Step 1: Full unit test suite**

Run: `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests`
Expected: all tests pass (baseline 199 + `OnboardingGateTests` (4) + `onboardingDefaultsToIncompleteAndPersistsWhenSet` (1) = 204)

- [ ] **Step 2: Full UI regression suite**

Run: `xcodebuild test -scheme WadeMoneyUITests -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyUITests/CoreFlowUITests`
Expected: all 5 tests pass (4 existing + `testOnboardingGuideReplayFromSettingsSkipAndDismiss`)

- [ ] **Step 3: Manual verification — fresh install shows the tour end-to-end**

```bash
xcrun simctl uninstall "iPhone 17e" com.kimhyeongi.WadeMoney
xcrun simctl install "iPhone 17e" /path/to/DerivedData/.../WadeMoney.app
xcrun simctl launch "iPhone 17e" com.kimhyeongi.WadeMoney
```

Take a screenshot (`xcrun simctl io "iPhone 17e" screenshot <path>`) after the splash animation finishes and confirm:
- Page 1 shows the mascot + welcome copy.
- "다음"/swipe advances through pages 2–3.
- "건너뛰기" on any of pages 1–3 jumps straight to page 4.
- Page 4's "알림 받기" triggers the real OS permission dialog; granting it and then checking Settings shows "오늘 지출 알림" on at 오후 10:00 (reusing the already-verified daily-reminder feature).
- After finishing the tour, relaunching the app does **not** show it again (flag persisted).

Also screenshot Settings → 도움말 and confirm the "가이드 다시 보기" row's `explore` icon renders as a glyph (not literal text "explore") — if it doesn't, the Material Symbols font subset bundled with the app doesn't include that ligature; swap to an icon name already proven elsewhere in this codebase (e.g. `category` or `auto_awesome`) and re-verify.

- [ ] **Step 4: Manual verification — existing users are excluded**

Using the same install (which now has the reminder setting, but more importantly should independently be tested for the "existing transaction data" path): run `testQuickAddExpenseFlowUpdatesHistory` once via `xcodebuild test -scheme WadeMoneyUITests -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyUITests/CoreFlowUITests/testQuickAddExpenseFlowUpdatesHistory` against a **fresh** install (`xcrun simctl uninstall` first, then let the test itself call `app.launch()` and save a transaction), then relaunch the app manually (`xcrun simctl launch`) and screenshot — confirm the tour does not appear (dashboard shows directly), demonstrating `hasExistingData` correctly suppresses it even though `didCompleteOnboarding` was never explicitly set to `true`.

- [ ] **Step 5: Check for unintended diffs**

Run: `git status --short | grep -v docs/design`
Expected: clean (no output) — only the design-tool artifacts under `docs/design/app-design-specification-analysis/` remain untouched/uncommitted, per this session's standing convention.

- [ ] **Step 6: Hand off**

Report task-by-task commit SHAs and verification results. Per this session's established pattern, do not push to `origin` unless the user explicitly asks.
