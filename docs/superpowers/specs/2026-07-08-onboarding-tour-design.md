# Onboarding Tour — Design

## Problem

New users open WadeMoney with no introduction to its core value (quick expense logging, AI-powered insights) and no chance to opt into the daily reminder notification (shipped separately, reachable only from Settings). There is currently no first-launch tour — `RootView` goes straight from the splash animation to the tab UI.

## Non-Goals

- No changes to the daily reminder notification system itself (`DailyReminderScheduler`, `NotificationScheduling`, `SettingsViewModel` reminder methods) — this feature only calls into that already-shipped infrastructure from the tour's last page.
- No per-page analytics/tracking.
- No A/B testing or variant copy — one fixed 4-page tour.
- No "resume where you left off" — reopening the tour (fresh install re-launch, or "가이드 다시 보기") always starts at page 1.

## 1. Audience & Gating

The tour shows once, automatically, only to genuinely new installs:

```
show onboarding ⟺ !didCompleteOnboarding && !hasExistingData
```

- `hasExistingData` is the same signal `WadeMoneyApp.swift` already computes for `CloudSyncMonitor` (`TransactionModel` fetch count > 0). It is threaded into `RootView` as an init parameter so existing users who update to this version — whose new `didCompleteOnboarding` field defaults to `false` — are not shown the tour.
- `didCompleteOnboarding` is a new `AppSettingsModel` field (CloudKit-synced, same pattern as `didSeedDefaultCategories`), so a user who completes the tour on one device won't see it again on a second device once sync catches up.
- Users who explicitly want to re-view the tour can open it anytime from Settings → 도움말 → "가이드 다시 보기", independent of the completion flag.

## 2. Data Model

`AppSettingsModel` gains one field, following the existing `didSeedDefaultCategories`/`aiEnabled` pattern:

```swift
var didCompleteOnboarding: Bool = false
```

`SettingsStore` gains:

```swift
func setDidCompleteOnboarding(_ completed: Bool) throws {
    let model = try settingsModel()
    model.didCompleteOnboarding = completed
    try context.save()
}
```

## 3. Page Content

Four pages, `TabView(.page)`, default page indicator hidden in favor of a custom dot row styled with `WadeColors` (mirrors the existing `SplashLoaderDots` pattern). Pages 1–3 are informational only; page 4 is interactive.

| # | Title | Body | Visual |
|---|-------|------|--------|
| 1. 소개 | "WadeMoney에 오신 걸 환영해요" | "가볍게 기록하는 하루 지출, 온디바이스 가계부예요" | Splash와 동일한 돼지 마스코트(`MascotView`, 정지 포즈) |
| 2. 빠른입력 | "몇 번의 탭이면 끝나요" | "가운데 + 버튼으로 금액·카테고리·메모만 입력하면 저장 끝" | FAB 아이콘 강조 |
| 3. AI인사이트 | "AI가 지출을 정리해드려요" | "카테고리 비중, 지출 추세를 온디바이스 AI가 자동으로 분석해요" | 도넛차트 아이콘 |
| 4. 알림권한 | "매일 잊지 않게 알려드릴게요" | "밤 10시(설정에서 변경 가능)에 오늘 지출을 기록했는지 알려드려요" | 알림 아이콘 + "알림 받기"/"나중에 하기" 버튼 |

## 4. Navigation Mechanics

- Pages 1–3: top-trailing "건너뛰기" button (jumps `selection` straight to page index 3) + bottom "다음" button (advances `selection` by one). Swiping also works since `TabView(.page)` provides it natively.
- Page 4: no "건너뛰기" (a user must not be able to skip past learning the reminder exists) and no "다음" — instead two terminal actions:
  - **"알림 받기"**: calls `SettingsViewModel.setDailyReminderEnabled(true)` (existing method — requests OS authorization, and on grant persists `dailyReminderEnabled=true` at the default 22:00 and schedules it; on denial, no-ops per that method's existing contract).
  - **"나중에 하기"**: no scheduler call at all — leaves the reminder off, exactly like a user who has never touched the toggle.
  - Both then call `SettingsStore.setDidCompleteOnboarding(true)` and dismiss.

## 5. Presentation

`OnboardingView` is a new full-screen view (own opaque `WadeColors.bg` background, not a translucent overlay) placed in `RootView`'s `ZStack` above `RootTabView`, at a higher `zIndex` than the update popup:

- `RootView` gains `@State private var showOnboarding: Bool`, initialized to the gating expression above (evaluated once at `RootView` init, mirroring how `showSplash` is already initialized eagerly).
- `SplashScreen.onFinished` now checks `showOnboarding` instead of unconditionally calling `checkForUpdateAfterSplash()`: if onboarding is due, show it and defer the update check until onboarding's own `onFinished` fires; otherwise run the update check immediately as today.
- `OnboardingView` itself only owns the tour's internal state (current page, the two reminder-page actions, and persisting `didCompleteOnboarding=true` when either terminal action fires) — it takes a single `onFinished: () -> Void` closure for "the tour is done, do whatever the presenting screen needs next." `RootView` passes a closure that sets `showOnboarding = false` and then triggers `checkForUpdateAfterSplash()` (so an update prompt can still appear right after, same as the existing splash → update-check flow for users who skip onboarding). Settings' re-view sheet (section 6) passes a closure that just dismisses the sheet.

## 6. Settings Re-entry

New row in Settings → 도움말 (alongside "앱 개선 의견 보내기"): "가이드 다시 보기". Tapping presents `OnboardingView` as a `.sheet`. This reuses the exact same view/completion-handler as the automatic first-launch flow — calling `setDidCompleteOnboarding(true)` again when it was already `true` is a harmless idempotent write, so no special-casing is needed for the re-view path.

## Files (expected)

- `WadeMoney/Models/AppSettingsModel.swift` — add `didCompleteOnboarding` field.
- `WadeMoney/Stores/SettingsStore.swift` — add `setDidCompleteOnboarding(_:)`.
- `WadeMoney/Screens/Onboarding/OnboardingView.swift` (new) — the `TabView(.page)` container, custom dot indicator, skip/next wiring.
- `WadeMoney/Screens/Onboarding/OnboardingPage.swift` (new) — the three informational page views (1–3), sharing a common layout.
- `WadeMoney/Screens/Onboarding/OnboardingReminderPage.swift` (new) — page 4, wired to `SettingsViewModel`.
- `WadeMoney/RootView.swift` — thread `hasExistingData` in from `WadeMoneyApp`, add `showOnboarding` state and the splash → onboarding → update-check sequencing.
- `WadeMoney/WadeMoneyApp.swift` — pass the already-computed `hasExistingData` into `RootView`.
- `WadeMoney/Screens/Settings/SettingsScreen.swift` — add "가이드 다시 보기" row + sheet case.
- Tests: `WadeMoneyTests/SettingsStoreTests.swift` (`setDidCompleteOnboarding` persistence), `WadeMoneyTests/SettingsViewModelTests.swift` or a new `OnboardingViewModel`-level test if page-4 logic is factored out for testability, `WadeMoneyUITests/CoreFlowUITests.swift` (fresh-install tour appears; existing-data install does not; skip jumps to page 4; "나중에 하기" completes without enabling the reminder).

## Verification

- Unit tests for the new `AppSettingsModel`/`SettingsStore` field and method (clamping/persistence pattern already established).
- UI tests: fresh install shows the tour and it's dismissable via both "나중에 하기" and "알림 받기" (denying the OS permission prompt in the "알림 받기" path, matching the existing manual-verification-only stance for real `UNUserNotificationCenter` calls); an install with existing transaction data does not show the tour; Settings' "가이드 다시 보기" reopens it on demand.
- Manual verification on a signed simulator: fresh install → tour appears → "알림 받기" → OS permission dialog → grant → Settings shows the reminder toggled on at 22:00, matching the already-shipped reminder feature's own manual verification from the prior feature.
