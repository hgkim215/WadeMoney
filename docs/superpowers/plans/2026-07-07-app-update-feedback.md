# App Update Prompt + Feedback Mail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a gentle App Store update prompt after launch and a Settings feedback-mail action for WadeMoney.

**Architecture:** Keep the two features split into focused units: pure version comparison, App Store lookup service, update prompt presentation, and feedback mail composition. `RootView` owns update presentation because it already owns splash timing; `SettingsScreen` owns the feedback entry because it already owns app settings/support rows.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing, MessageUI, UIKit pasteboard, iTunes Lookup API.

## Global Constraints

- Update prompt is gentle and dismissible, not a forced update.
- Check App Store updates on launch and foreground return.
- Show update prompt only after `SplashScreen` finishes.
- Gate App Store update checks to once every 24 hours using `UserDefaults`.
- App Store lookup failures show no UI and do not block app launch.
- Feedback recipient is `hgkim215@gmail.com`.
- Feedback subject is `[WadeMoney] 앱 개선 의견`.
- Feedback is sent through the user's configured Mail app; WadeMoney does not add a feedback backend.
- If Mail is unavailable, copy `hgkim215@gmail.com` and show `메일 앱이 없어 주소를 복사했어요`.
- Keep all copy Korean-first and consistent with WadeMoney's quiet settings tone.
- Do not stage or modify unrelated `docs/design/app-design-specification-analysis` artifacts.

---

## File Structure

- Create `WadeMoney/Update/AppVersion.swift`
  - Pure dotted-version comparison.
- Create `WadeMoney/Update/UpdateChecker.swift`
  - iTunes Lookup URL construction, JSON decoding, 24-hour gate, nil-on-error behavior.
- Create `WadeMoney/Update/UpdateAvailablePopup.swift`
  - WadeMoney-styled overlay card with update and later actions.
- Modify `WadeMoney/RootView.swift`
  - Delay update check until splash completion and repeat on foreground return.
- Create `WadeMoney/Support/FeedbackMailDraft.swift`
  - Pure email recipient, subject, and body construction.
- Create `WadeMoney/Screens/Settings/MailComposeView.swift`
  - SwiftUI wrapper for `MFMailComposeViewController`.
- Create `WadeMoney/DesignSystem/WadeToast.swift`
  - Reusable toast view matching the existing RootTabView toast.
- Modify `WadeMoney/Screens/RootTabView.swift`
  - Use `WadeToast` instead of the private toast builder.
- Modify `WadeMoney/Screens/Settings/SettingsScreen.swift`
  - Add the `도움말` section, feedback mail sheet, clipboard fallback, and toast.
- Create `WadeMoneyTests/AppVersionTests.swift`
  - Version comparison tests.
- Create `WadeMoneyTests/UpdateCheckerTests.swift`
  - Lookup parsing and 24-hour gate tests.
- Create `WadeMoneyTests/FeedbackMailDraftTests.swift`
  - Recipient, subject, and diagnostics tests.
- Modify `docs/superpowers/plans/2026-07-02-codex-ui-ux-handoff.md`
  - Record implementation summary and verification before final response.

---

### Task 1: AppVersion Pure Comparison

**Files:**
- Create: `WadeMoney/Update/AppVersion.swift`
- Create: `WadeMoneyTests/AppVersionTests.swift`

**Interfaces:**
- Produces: `enum AppVersion { static func isVersion(_ latest: String, newerThan current: String) -> Bool }`
- Consumes: none.

- [ ] **Step 1: Write the failing tests**

Create `WadeMoneyTests/AppVersionTests.swift`:

```swift
import Testing
@testable import WadeMoney

struct AppVersionTests {
    @Test func newerPatchIsNewer() {
        #expect(AppVersion.isVersion("1.0.1", newerThan: "1.0.0") == true)
    }

    @Test func newerMinorIsNewer() {
        #expect(AppVersion.isVersion("1.2.0", newerThan: "1.1.9") == true)
    }

    @Test func newerMajorIsNewer() {
        #expect(AppVersion.isVersion("2.0", newerThan: "1.9.9") == true)
    }

    @Test func sameVersionIsNotNewer() {
        #expect(AppVersion.isVersion("1.0.0", newerThan: "1.0.0") == false)
    }

    @Test func olderVersionIsNotNewer() {
        #expect(AppVersion.isVersion("1.0.0", newerThan: "1.0.1") == false)
    }

    @Test func missingComponentsCompareAsZero() {
        #expect(AppVersion.isVersion("1.4", newerThan: "1.4.0") == false)
        #expect(AppVersion.isVersion("1.4.1", newerThan: "1.4") == true)
    }

    @Test func comparesNumericallyInsteadOfLexically() {
        #expect(AppVersion.isVersion("1.10.0", newerThan: "1.9.0") == true)
    }

    @Test func nonNumericComponentsFallBackToZero() {
        #expect(AppVersion.isVersion("1.0.0", newerThan: "1.x.0") == false)
        #expect(AppVersion.isVersion("1.0.1", newerThan: "1.x.0") == true)
    }
}
```

- [ ] **Step 2: Run the tests and verify they fail**

Run:

```bash
xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/AppVersionTests
```

Expected: FAIL because `AppVersion` is not defined.

- [ ] **Step 3: Implement the version helper**

Create `WadeMoney/Update/AppVersion.swift`:

```swift
enum AppVersion {
    static func isVersion(_ latest: String, newerThan current: String) -> Bool {
        let latestParts = numericParts(latest)
        let currentParts = numericParts(current)
        let count = max(latestParts.count, currentParts.count)

        for index in 0..<count {
            let latestValue = index < latestParts.count ? latestParts[index] : 0
            let currentValue = index < currentParts.count ? currentParts[index] : 0
            if latestValue != currentValue {
                return latestValue > currentValue
            }
        }

        return false
    }

    private static func numericParts(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0) ?? 0 }
    }
}
```

- [ ] **Step 4: Run the tests and verify they pass**

Run:

```bash
xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/AppVersionTests
```

Expected: PASS for all `AppVersionTests`.

- [ ] **Step 5: Commit**

```bash
git add WadeMoney/Update/AppVersion.swift WadeMoneyTests/AppVersionTests.swift
git commit -m "feat(update): add app version comparison"
```

---

### Task 2: UpdateChecker App Store Lookup

**Files:**
- Create: `WadeMoney/Update/UpdateChecker.swift`
- Create: `WadeMoneyTests/UpdateCheckerTests.swift`

**Interfaces:**
- Consumes: `AppVersion.isVersion(_:newerThan:)`
- Produces:
  - `struct UpdateInfo: Equatable, Sendable { let version: String; let storeURL: URL }`
  - `struct UpdateChecker { func check() async -> UpdateInfo? }`

- [ ] **Step 1: Write the failing tests**

Create `WadeMoneyTests/UpdateCheckerTests.swift`:

```swift
import Foundation
import Testing
@testable import WadeMoney

struct UpdateCheckerTests {
    private func defaults(_ name: String = UUID().uuidString) -> UserDefaults {
        let suiteName = "UpdateCheckerTests-\(name)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func json(version: String, url: String = "https://apps.apple.com/kr/app/wademoney/id1234567890") -> Data {
        """
        {
          "resultCount": 1,
          "results": [
            {
              "version": "\(version)",
              "trackViewUrl": "\(url)"
            }
          ]
        }
        """.data(using: .utf8)!
    }

    @Test func returnsInfoWhenLookupVersionIsNewer() async {
        let defaults = defaults("newer")
        var requestedURL: URL?
        let checker = UpdateChecker(
            bundleID: "com.kimhyeongi.WadeMoney",
            currentVersion: "1.0.0",
            defaults: defaults,
            now: { Date(timeIntervalSince1970: 1_000) },
            fetch: { url in
                requestedURL = url
                return json(version: "1.0.1")
            }
        )

        let info = await checker.check()

        #expect(info == UpdateInfo(version: "1.0.1", storeURL: URL(string: "https://apps.apple.com/kr/app/wademoney/id1234567890")!))
        #expect(requestedURL?.absoluteString.contains("bundleId=com.kimhyeongi.WadeMoney") == true)
        #expect(requestedURL?.absoluteString.contains("country=kr") == true)
    }

    @Test func returnsNilWhenLookupVersionIsSame() async {
        let checker = UpdateChecker(
            bundleID: "com.kimhyeongi.WadeMoney",
            currentVersion: "1.0.0",
            defaults: defaults("same"),
            now: { Date(timeIntervalSince1970: 1_000) },
            fetch: { _ in json(version: "1.0.0") }
        )

        let info = await checker.check()

        #expect(info == nil)
    }

    @Test func returnsNilForMalformedJSON() async {
        let checker = UpdateChecker(
            bundleID: "com.kimhyeongi.WadeMoney",
            currentVersion: "1.0.0",
            defaults: defaults("malformed"),
            now: { Date(timeIntervalSince1970: 1_000) },
            fetch: { _ in Data("not-json".utf8) }
        )

        let info = await checker.check()

        #expect(info == nil)
    }

    @Test func returnsNilForInvalidStoreURL() async {
        let checker = UpdateChecker(
            bundleID: "com.kimhyeongi.WadeMoney",
            currentVersion: "1.0.0",
            defaults: defaults("bad-url"),
            now: { Date(timeIntervalSince1970: 1_000) },
            fetch: { _ in json(version: "2.0.0", url: "not a url") }
        )

        let info = await checker.check()

        #expect(info == nil)
    }

    @Test func respectsTwentyFourHourGate() async {
        let defaults = defaults("gate")
        var fetchCount = 0
        var now = Date(timeIntervalSince1970: 1_000)
        let checker = UpdateChecker(
            bundleID: "com.kimhyeongi.WadeMoney",
            currentVersion: "1.0.0",
            defaults: defaults,
            now: { now },
            fetch: { _ in
                fetchCount += 1
                return json(version: "2.0.0")
            }
        )

        _ = await checker.check()
        now = Date(timeIntervalSince1970: 1_000 + 60)
        let second = await checker.check()
        now = Date(timeIntervalSince1970: 1_000 + 24 * 60 * 60 + 1)
        _ = await checker.check()

        #expect(second == nil)
        #expect(fetchCount == 2)
    }
}
```

- [ ] **Step 2: Run the tests and verify they fail**

Run:

```bash
xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/UpdateCheckerTests
```

Expected: FAIL because `UpdateChecker` and `UpdateInfo` are not defined.

- [ ] **Step 3: Implement the update checker**

Create `WadeMoney/Update/UpdateChecker.swift`:

```swift
import Foundation

struct UpdateInfo: Equatable, Sendable {
    let version: String
    let storeURL: URL
}

struct UpdateChecker {
    typealias Fetch = @Sendable (URL) async throws -> Data

    private let bundleID: String?
    private let currentVersion: String?
    private let defaults: UserDefaults
    private let now: @Sendable () -> Date
    private let fetch: Fetch
    private let country: String
    private let interval: TimeInterval
    private let lastCheckKey = "lastAppStoreUpdateCheckDate"

    init(
        bundleID: String? = Bundle.main.bundleIdentifier,
        currentVersion: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = Date.init,
        country: String = "kr",
        interval: TimeInterval = 24 * 60 * 60,
        fetch: @escaping Fetch = { url in
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        }
    ) {
        self.bundleID = bundleID
        self.currentVersion = currentVersion
        self.defaults = defaults
        self.now = now
        self.country = country
        self.interval = interval
        self.fetch = fetch
    }

    func check() async -> UpdateInfo? {
        guard shouldCheckNow() else { return nil }
        defaults.set(now(), forKey: lastCheckKey)

        guard let bundleID, let currentVersion, var components = URLComponents(string: "https://itunes.apple.com/lookup") else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "country", value: country)
        ]

        guard let url = components.url else { return nil }

        do {
            let data = try await fetch(url)
            let response = try JSONDecoder().decode(LookupResponse.self, from: data)
            guard let result = response.results.first,
                  let storeURL = URL(string: result.trackViewUrl),
                  AppVersion.isVersion(result.version, newerThan: currentVersion) else {
                return nil
            }
            return UpdateInfo(version: result.version, storeURL: storeURL)
        } catch {
            return nil
        }
    }

    private func shouldCheckNow() -> Bool {
        guard let last = defaults.object(forKey: lastCheckKey) as? Date else {
            return true
        }
        return now().timeIntervalSince(last) >= interval
    }
}

private struct LookupResponse: Decodable {
    let results: [LookupResult]
}

private struct LookupResult: Decodable {
    let version: String
    let trackViewUrl: String
}
```

- [ ] **Step 4: Run the tests and verify they pass**

Run:

```bash
xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/UpdateCheckerTests
```

Expected: PASS for all `UpdateCheckerTests`.

- [ ] **Step 5: Commit**

```bash
git add WadeMoney/Update/UpdateChecker.swift WadeMoneyTests/UpdateCheckerTests.swift
git commit -m "feat(update): add App Store lookup checker"
```

---

### Task 3: Update Popup And RootView Integration

**Files:**
- Create: `WadeMoney/Update/UpdateAvailablePopup.swift`
- Modify: `WadeMoney/RootView.swift`

**Interfaces:**
- Consumes:
  - `UpdateChecker.check() async -> UpdateInfo?`
  - `UpdateInfo.version`
  - `UpdateInfo.storeURL`
- Produces:
  - `UpdateAvailablePopup(info:onUpdate:onLater:)`
  - `RootView.checkForUpdateAfterSplash()` private behavior

- [ ] **Step 1: Add the update popup view**

Create `WadeMoney/Update/UpdateAvailablePopup.swift`:

```swift
import SwiftUI

struct UpdateAvailablePopup: View {
    @Environment(\.colorScheme) private var scheme

    let info: UpdateInfo
    var onUpdate: () -> Void
    var onLater: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.36)
                .ignoresSafeArea()
                .onTapGesture { onLater() }

            VStack(spacing: 18) {
                Icon("system_update_alt", size: 36)
                    .foregroundStyle(WadeColors.primary(scheme))
                    .frame(width: 64, height: 64)
                    .background(WadeColors.primarysoft(scheme), in: Circle())

                VStack(spacing: 7) {
                    Text("새 버전이 있어요")
                        .font(WadeFont.pretendard(20, weight: .heavy))
                        .foregroundStyle(WadeColors.ink(scheme))
                    Text("버전 \(info.version)이 준비됐어요. 업데이트하고 최신 기능을 받아보세요.")
                        .font(WadeFont.pretendard(14, weight: .semibold))
                        .foregroundStyle(WadeColors.ink2(scheme))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                VStack(spacing: 10) {
                    Button(action: onUpdate) {
                        Text("업데이트")
                            .font(WadeFont.pretendard(16, weight: .heavy))
                            .foregroundStyle(WadeColors.onPrimary(scheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(WadeColors.primary(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: onLater) {
                        Text("나중에")
                            .font(WadeFont.pretendard(14.5, weight: .bold))
                            .foregroundStyle(WadeColors.ink3(scheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(WadeColors.card(scheme), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(scheme == .dark ? 0.38 : 0.16), radius: 24, y: 14)
            .padding(.horizontal, WadeSpacing.screenH)
        }
    }
}
```

- [ ] **Step 2: Integrate the popup into RootView**

Modify `WadeMoney/RootView.swift` to this shape:

```swift
import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Query private var settingsModels: [AppSettingsModel]
    @State private var showSplash = SplashVisibility.shouldShowOnLaunch()
    @State private var pendingUpdate: UpdateInfo?

    private let updateChecker = UpdateChecker()

    /// 여러 기기의 CloudKit 병합으로 설정 행이 잠깐 중복될 수 있다 — SettingsStore와 동일하게
    /// id 최솟값 행을 결정적으로 채택한다(둘 다 같은 규칙이어야 기기 간 동일하게 보인다).
    private var appearance: AppAppearance {
        let winner = settingsModels.min { $0.id < $1.id }
        return AppAppearance(rawValue: winner?.appearanceRaw ?? 0) ?? .system
    }

    var body: some View {
        ZStack {
            RootTabView()
            if let pendingUpdate, !showSplash {
                UpdateAvailablePopup(
                    info: pendingUpdate,
                    onUpdate: {
                        openURL(pendingUpdate.storeURL)
                        self.pendingUpdate = nil
                    },
                    onLater: {
                        self.pendingUpdate = nil
                    }
                )
                .transition(.opacity)
                .zIndex(1)
            }
            if showSplash {
                SplashScreen(onFinished: {
                    showSplash = false
                    Task { await checkForUpdateAfterSplash() }
                })
                .zIndex(2)
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .task {
            guard !showSplash else { return }
            await checkForUpdateAfterSplash()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, !showSplash else { return }
            Task { await checkForUpdateAfterSplash() }
        }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .debugTriggerUpdatePopup)) { _ in
            pendingUpdate = UpdateInfo(
                version: "99.0.0",
                storeURL: URL(string: "https://apps.apple.com/kr/app/wademoney/id1234567890")!
            )
        }
        #endif
    }

    @MainActor
    private func checkForUpdateAfterSplash() async {
        guard pendingUpdate == nil else { return }
        if let info = await updateChecker.check() {
            withAnimation(.easeInOut(duration: 0.2)) {
                pendingUpdate = info
            }
        }
    }
}

#if DEBUG
extension Notification.Name {
    static let debugTriggerUpdatePopup = Notification.Name("DebugTriggerUpdatePopup")
}
#endif

#Preview {
    RootView()
}
```

- [ ] **Step 3: Build to catch UI and concurrency issues**

Run:

```bash
xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run the existing test suite**

Run:

```bash
xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add WadeMoney/Update/UpdateAvailablePopup.swift WadeMoney/RootView.swift
git commit -m "feat(update): show update prompt after launch"
```

---

### Task 4: Feedback Mail And Settings Entry

**Files:**
- Create: `WadeMoney/Support/FeedbackMailDraft.swift`
- Create: `WadeMoney/Screens/Settings/MailComposeView.swift`
- Create: `WadeMoney/DesignSystem/WadeToast.swift`
- Create: `WadeMoneyTests/FeedbackMailDraftTests.swift`
- Modify: `WadeMoney/Screens/Settings/SettingsScreen.swift`
- Modify: `WadeMoney/Screens/RootTabView.swift`

**Interfaces:**
- Produces:
  - `struct FeedbackMailDraft { let recipient: String; let subject: String; let body: String }`
  - `struct MailComposeView: UIViewControllerRepresentable`
  - `struct WadeToast: View`
- Consumes:
  - `WadeColors.toastbg(_:)`
  - `WadeColors.toastfg(_:)`
  - `WadeFont.pretendard`

- [ ] **Step 1: Write the failing feedback draft tests**

Create `WadeMoneyTests/FeedbackMailDraftTests.swift`:

```swift
import Testing
@testable import WadeMoney

struct FeedbackMailDraftTests {
    @Test func recipientAndSubjectAreFixed() {
        let draft = FeedbackMailDraft(
            appVersion: "1.0",
            build: "7",
            systemVersion: "26.0",
            deviceModel: "iPhone18,1"
        )

        #expect(draft.recipient == "hgkim215@gmail.com")
        #expect(draft.subject == "[WadeMoney] 앱 개선 의견")
    }

    @Test func bodyStartsWithFeedbackPrompt() {
        let draft = FeedbackMailDraft(
            appVersion: "1.0",
            build: "7",
            systemVersion: "26.0",
            deviceModel: "iPhone18,1"
        )

        #expect(draft.body.contains("앱을 쓰면서 불편했던 점이나 개선되면 좋을 부분을 적어주세요"))
    }

    @Test func bodyContainsDiagnostics() {
        let draft = FeedbackMailDraft(
            appVersion: "1.2.3",
            build: "9",
            systemVersion: "26.1",
            deviceModel: "iPhone18,2"
        )

        #expect(draft.body.contains("앱 버전: 1.2.3 (빌드 9)"))
        #expect(draft.body.contains("iOS: 26.1"))
        #expect(draft.body.contains("기기: iPhone18,2"))
    }
}
```

- [ ] **Step 2: Run the tests and verify they fail**

Run:

```bash
xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/FeedbackMailDraftTests
```

Expected: FAIL because `FeedbackMailDraft` is not defined.

- [ ] **Step 3: Implement the feedback draft**

Create `WadeMoney/Support/FeedbackMailDraft.swift`:

```swift
import Foundation

struct FeedbackMailDraft {
    let recipient: String
    let subject: String
    let body: String

    init(appVersion: String, build: String, systemVersion: String, deviceModel: String) {
        recipient = "hgkim215@gmail.com"
        subject = "[WadeMoney] 앱 개선 의견"
        body = """
        앱을 쓰면서 불편했던 점이나 개선되면 좋을 부분을 적어주세요:


        ──────────────
        아래 정보는 문제 확인에만 사용돼요.
        앱 버전: \(appVersion) (빌드 \(build))
        iOS: \(systemVersion)
        기기: \(deviceModel)
        """
    }
}
```

- [ ] **Step 4: Add the Mail compose wrapper**

Create `WadeMoney/Screens/Settings/MailComposeView.swift`:

```swift
import MessageUI
import SwiftUI

struct MailComposeView: UIViewControllerRepresentable {
    let draft: FeedbackMailDraft
    var onFinish: () -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([draft.recipient])
        controller.setSubject(draft.subject)
        controller.setMessageBody(draft.body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            onFinish()
        }
    }
}
```

- [ ] **Step 5: Add the reusable toast view**

Create `WadeMoney/DesignSystem/WadeToast.swift`:

```swift
import SwiftUI

struct WadeToast: View {
    @Environment(\.colorScheme) private var scheme

    let message: String

    var body: some View {
        Text(message)
            .font(WadeFont.pretendard(13.5, weight: .bold))
            .foregroundStyle(WadeColors.toastfg(scheme))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(WadeColors.toastbg(scheme), in: Capsule())
            .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
    }
}
```

- [ ] **Step 6: Replace RootTabView's private toast builder**

Modify the stats toast block in `WadeMoney/Screens/RootTabView.swift`:

```swift
if showStatsToast {
    WadeToast(message: "통계는 나중에 업데이트될 예정이에요")
        .padding(.horizontal, WadeSpacing.screenH)
        .padding(.bottom, 76)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .offset(y: 10)),
            removal: .opacity.combined(with: .offset(y: 6))
        ))
        .allowsHitTesting(false)
}
```

Remove the private `toast(_:)` function from `RootTabView`.

- [ ] **Step 7: Add SettingsScreen mail state and imports**

Modify the imports at the top of `WadeMoney/Screens/Settings/SettingsScreen.swift`:

```swift
import MessageUI
import SwiftData
import SwiftUI
import UIKit
import WadeMoneyCore
```

Add state next to the existing state properties:

```swift
@State private var settingsToast: String?
@State private var settingsToastTask: Task<Void, Never>?
```

Add a new sheet case:

```swift
private enum SettingsSheet: Identifiable {
    case budget
    case monthStartDay
    case share(URL)
    case feedbackMail

    var id: String {
        switch self {
        case .budget: return "budget"
        case .monthStartDay: return "monthStartDay"
        case .share(let url): return "share-\(url.absoluteString)"
        case .feedbackMail: return "feedbackMail"
        }
    }
}
```

- [ ] **Step 8: Add the Settings support row and toast overlay**

Add this section before the existing `정보` section in `SettingsScreen.body`:

```swift
section("도움말") {
    row(
        icon: "mail",
        tint: WadeColors.primary(scheme),
        label: "앱 개선 의견 보내기",
        subtitle: "메일로 의견을 보낼 수 있어요",
        trailing: nil
    ) {
        startFeedbackMail()
    }
}
```

Wrap the `NavigationStack` with a `ZStack(alignment: .bottom)` inside `body` or add an overlay after the existing `.sheet(item:)` modifier:

```swift
.overlay(alignment: .bottom) {
    if let settingsToast {
        WadeToast(message: settingsToast)
            .padding(.horizontal, WadeSpacing.screenH)
            .padding(.bottom, 16)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(y: 10)),
                removal: .opacity.combined(with: .offset(y: 6))
            ))
            .allowsHitTesting(false)
    }
}
.onDisappear {
    settingsToastTask?.cancel()
}
```

- [ ] **Step 9: Add feedback sheet content and helper methods**

Add `.feedbackMail` to `sheetContent(_:)`:

```swift
case .feedbackMail:
    MailComposeView(draft: makeFeedbackDraft()) {
        presentedSheet = nil
    }
    .ignoresSafeArea()
```

Add these helper methods inside `SettingsScreen`:

```swift
private func startFeedbackMail() {
    if MFMailComposeViewController.canSendMail() {
        presentedSheet = .feedbackMail
    } else {
        UIPasteboard.general.string = "hgkim215@gmail.com"
        showSettingsToast("메일 앱이 없어 주소를 복사했어요")
    }
}

private func showSettingsToast(_ message: String) {
    settingsToastTask?.cancel()
    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
        settingsToast = message
    }
    settingsToastTask = Task {
        try? await Task.sleep(for: .seconds(1.8))
        guard !Task.isCancelled else { return }
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.2)) {
                settingsToast = nil
            }
        }
    }
}

private func makeFeedbackDraft() -> FeedbackMailDraft {
    FeedbackMailDraft(
        appVersion: Self.appVersion,
        build: Self.buildNumber,
        systemVersion: UIDevice.current.systemVersion,
        deviceModel: Self.deviceModel
    )
}
```

Add these static helpers near `appVersion`:

```swift
static let buildNumber =
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"

static var deviceModel: String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let mirror = Mirror(reflecting: systemInfo.machine)
    let bytes = mirror.children.compactMap { $0.value as? Int8 }
    return String(
        bytes: bytes.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) },
        encoding: .utf8
    ) ?? "?"
}
```

- [ ] **Step 10: Run focused tests**

Run:

```bash
xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests/FeedbackMailDraftTests
```

Expected: PASS for all `FeedbackMailDraftTests`.

- [ ] **Step 11: Build to verify MessageUI/UIKit integration**

Run:

```bash
xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 12: Commit**

```bash
git add WadeMoney/Support/FeedbackMailDraft.swift WadeMoney/Screens/Settings/MailComposeView.swift WadeMoney/DesignSystem/WadeToast.swift WadeMoneyTests/FeedbackMailDraftTests.swift WadeMoney/Screens/Settings/SettingsScreen.swift WadeMoney/Screens/RootTabView.swift
git commit -m "feat(settings): add feedback mail action"
```

---

### Task 5: Final Verification And Handoff

**Files:**
- Modify: `docs/superpowers/plans/2026-07-02-codex-ui-ux-handoff.md`

**Interfaces:**
- Consumes all previous tasks.
- Produces verified branch state and handoff entry.

- [ ] **Step 1: Run WadeMoneyCore tests**

Run:

```bash
swift test --package-path WadeMoneyCore
```

Expected: all WadeMoneyCore tests pass.

- [ ] **Step 2: Run full app unit tests**

Run:

```bash
xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Expected: all WadeMoneyTests pass.

- [ ] **Step 3: Build and run the app on the smallest simulator**

Run:

```bash
xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Expected: BUILD SUCCEEDED.

Then launch with XcodeBuildMCP or Xcode and confirm:

- Splash appears first.
- Update popup does not appear during splash.
- DEBUG update trigger, if implemented, shows the update popup after splash.
- `나중에` dismisses the popup.
- Settings contains `도움말` > `앱 개선 의견 보내기`.
- On simulator without Mail configured, tapping feedback copies the address and shows `메일 앱이 없어 주소를 복사했어요`.

- [ ] **Step 4: Run whitespace checks**

Run:

```bash
git diff --check
```

Expected: no whitespace errors.

- [ ] **Step 5: Update handoff**

Append this entry to `docs/superpowers/plans/2026-07-02-codex-ui-ux-handoff.md`. Replace the commit list with the commit SHAs created during execution. In the verification bullets, write the exact command outcome from Steps 1-4, such as `passed 37 tests`, `passed 145 tests`, `BUILD SUCCEEDED`, or the exact failure text if a check fails.

```markdown
## 2026-07-07 Codex Implementation: App Update Prompt + Feedback Mail

User request:

- Add WadeNote-style App Store update prompt.
- Add Settings feedback mail action.

What changed:

- Added pure app version comparison.
- Added App Store iTunes Lookup checker with 24-hour gate.
- Added update popup after splash / foreground return.
- Added Settings feedback mail action with Mail compose and clipboard fallback.
- Added reusable WadeToast.

Files touched:

- `WadeMoney/Update/AppVersion.swift`
- `WadeMoney/Update/UpdateChecker.swift`
- `WadeMoney/Update/UpdateAvailablePopup.swift`
- `WadeMoney/RootView.swift`
- `WadeMoney/Support/FeedbackMailDraft.swift`
- `WadeMoney/Screens/Settings/MailComposeView.swift`
- `WadeMoney/DesignSystem/WadeToast.swift`
- `WadeMoney/Screens/RootTabView.swift`
- `WadeMoney/Screens/Settings/SettingsScreen.swift`
- `WadeMoneyTests/AppVersionTests.swift`
- `WadeMoneyTests/UpdateCheckerTests.swift`
- `WadeMoneyTests/FeedbackMailDraftTests.swift`

Verification:

- `swift test --package-path WadeMoneyCore`: record the exact pass/fail result from Step 1.
- `xcodebuild test -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`: record the exact pass/fail result from Step 2.
- `xcodebuild build -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17e'`: record the exact build result from Step 3.
- `git diff --check`: record the exact whitespace-check result from Step 4.

Known limitations / follow-up:

- If the App Store URL handoff cannot be fully verified in Simulator, state that only `openURL` handoff was attempted and recommend a real-device check.
- If Mail is not configured in Simulator, state that the clipboard fallback toast was verified instead of the compose sheet.
```

- [ ] **Step 6: Commit handoff if it is safe to do so**

If `docs/superpowers/plans/2026-07-02-codex-ui-ux-handoff.md` contains only current-task changes or the user explicitly wants the existing local handoff edits included:

```bash
git add docs/superpowers/plans/2026-07-02-codex-ui-ux-handoff.md
git commit -m "docs: update handoff for update and feedback features"
```

If the handoff file already contains unrelated uncommitted edits from another agent, leave it unstaged and clearly report that it was updated locally but not committed.
