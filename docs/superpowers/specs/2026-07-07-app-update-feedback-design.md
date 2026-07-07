# WadeMoney App Update Prompt + Feedback Mail Design

Date: 2026-07-07
Status: Approved for planning

## User Goal

Add two WadeNote-style support features to WadeMoney:

1. When the App Store has a newer version, tell the user after app launch and link directly to the App Store.
2. Add a Settings entry where the user can send app improvement feedback by email.

The user approved the WadeNote-style approach and approved using `hgkim215@gmail.com` as the feedback recipient.

## Product Decisions

- Use a gentle update prompt, not a forced update.
- Check for App Store updates automatically on launch and when the app returns to foreground.
- Show the update prompt only after the splash screen has finished so the first launch animation is not visually interrupted.
- Gate update checks to once every 24 hours using `UserDefaults`.
- If the App Store lookup fails, the app shows nothing and continues normally.
- Feedback email is sent by the user's configured Mail app. WadeMoney does not send feedback through its own backend.
- If Mail is unavailable, copy `hgkim215@gmail.com` to the clipboard and show a small WadeMoney-style toast.

## Architecture

### `AppVersion`

Pure version comparison helper.

- Input: current version string and latest App Store version string.
- Handles dotted numeric versions such as `1.0`, `1.0.1`, and `1.10.0`.
- Missing components are treated as zero, so `1.4` equals `1.4.0`.
- Non-numeric components fall back to zero for a safe comparison.

### `UpdateChecker`

Small async service that checks Apple's iTunes Lookup API.

- Uses the app bundle identifier from `Bundle.main.bundleIdentifier`.
- Calls `https://itunes.apple.com/lookup?bundleId=<bundle>&country=kr`.
- Reads `version` and `trackViewUrl` from the first result.
- Returns `UpdateInfo(version:storeURL:)` only when the App Store version is newer than the installed app version.
- Records the last check time before the network request so repeated failures do not retry every launch.
- Swallows all errors and returns `nil`.

For testability, the implementation should allow injecting:

- current date / clock,
- `UserDefaults`,
- current version,
- bundle identifier,
- network fetch function or URLSession adapter.

### `UpdateAvailablePopup`

SwiftUI overlay shown from `RootView`.

- Uses WadeMoney colors, font, radius, and spacing tokens.
- Copy:
  - Title: `새 버전이 있어요`
  - Body: `버전 {version}이 준비됐어요. 업데이트하고 최신 기능을 받아보세요.`
  - Primary button: `업데이트`
  - Secondary button: `나중에`
- `업데이트` opens `UpdateInfo.storeURL` via `openURL`, then dismisses the popup.
- `나중에` and tapping the dimmed background dismiss the popup.

### `RootView` Integration

`RootView` already owns the splash overlay, so it should own the update prompt state too.

- Add `@Environment(\.scenePhase)` and `@Environment(\.openURL)`.
- Add `@State private var pendingUpdate: UpdateInfo?`.
- Start the first check only after `showSplash` becomes false.
- On foreground return, run the same check, respecting the 24-hour gate.
- Render the update popup above `RootTabView` and below any active splash overlay.

If a DEBUG-only manual trigger is useful for real-device verification, add it behind `#if DEBUG` and keep it out of release behavior.

## Feedback Mail

### `FeedbackMailDraft`

Pure value that builds the email contents.

- Recipient: `hgkim215@gmail.com`
- Subject: `[WadeMoney] 앱 개선 의견`
- Body starts with a short prompt:

```text
앱을 쓰면서 불편했던 점이나 개선되면 좋을 부분을 적어주세요:
```

Then append diagnostics:

- app version,
- build number,
- iOS version,
- device model.

### `MailComposeView`

SwiftUI wrapper around `MFMailComposeViewController`.

- Accepts `FeedbackMailDraft`.
- Sets recipient, subject, and plain text body.
- Calls `onFinish` for sent, cancelled, saved, or failed results.

### Settings Integration

Add a quiet support row to `SettingsScreen`.

Recommended section:

- Add a new section titled `도움말` before `정보`.
- Row label: `앱 개선 의견 보내기`
- Subtitle: `메일로 의견을 보낼 수 있어요`
- Icon: `mail` or a matching Material Symbols mail icon.

Interaction:

- If `MFMailComposeViewController.canSendMail()` is true, present `MailComposeView`.
- Otherwise set `UIPasteboard.general.string = "hgkim215@gmail.com"` and show toast text: `메일 앱이 없어 주소를 복사했어요`.

The toast should reuse WadeMoney's current toast visual language: dark/light capsule, compact text, subtle rise, and bottom spacing that clears the tab bar or sheet safe area.

## Error Handling

- Update check network failure: no UI.
- Lookup returns no App Store result: no UI.
- Lookup returns same or older version: no UI.
- Invalid App Store URL: no UI.
- Mail unavailable: copy recipient email and show toast.
- Mail compose failure result: dismiss compose sheet; do not show extra error unless a future UX pass asks for it.

## Testing Plan

Unit tests:

- `AppVersionTests`
  - newer patch, minor, and major versions are detected.
  - same version is not newer.
  - older version is not newer.
  - missing components compare as zeros.
  - numeric comparison beats lexical comparison (`1.10.0 > 1.9.0`).
- `UpdateCheckerTests`
  - returns `UpdateInfo` for newer lookup response.
  - returns nil for same/older version.
  - returns nil for malformed JSON or missing URL.
  - respects the 24-hour gate.
- `FeedbackMailDraftTests`
  - recipient and subject are fixed.
  - body includes prompt and diagnostics.

Integration / simulator checks:

- Build and run on the smallest available simulator.
- Trigger a DEBUG update popup or inject a fake newer version and confirm the popup appears after splash.
- Tap `나중에` and confirm it dismisses.
- Tap `업데이트` and confirm App Store URL handoff is attempted.
- Open Settings and confirm the feedback row fits the current design.
- On a simulator without configured Mail, tap feedback and confirm the copy-address toast appears.

## Non-Goals

- No forced update lockout.
- No custom feedback backend.
- No in-app feedback form.
- No Settings row for manual update checks unless requested later.
- No analytics or tracking around update prompts or feedback taps.
