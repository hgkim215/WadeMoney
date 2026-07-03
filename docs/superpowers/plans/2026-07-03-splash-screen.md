# 스플래시 화면(마스코트 도넛 베어물기) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 콜드 스타트 시 앱 아이콘과 동일한 벡터 마스코트가 도넛을 베어무는 애니메이션을 보여주는 커스텀 스플래시 화면을 추가한다.

**Architecture:** 마스코트를 그리는 순수 View(`MascotView`)와 애니메이션 진행도를 담는 상태(`MascotAnimationState`)를 분리한다. 애니메이션 구간 길이는 UI와 무관한 순수 데이터(`SplashTimeline`)로 뽑아내 유닛 테스트로 검증한다. `SplashScreen`이 이 둘을 조합해 타임라인대로 `withAnimation`을 순차 호출하고, `RootView`가 콜드 스타트에만 `SplashScreen`을 `RootTabView` 위에 얹었다가 걷어낸다.

**Tech Stack:** SwiftUI (iOS 26 타깃), Swift Testing(`@Test`/`#expect`), 기존 `WadeColors`/`Color(hex:)` 디자인 시스템 그대로 사용. 새 의존성 없음.

## Global Constraints

- 스플래시 전체 재생 시간(기본, Reduce Motion 꺼짐)은 약 1.4초 — spec의 타임라인 표(등장 0.35s / 도넛 접근 0.40s / 베어물기 0.20s / 정지 0.25s / 퇴장 0.20s) 값을 그대로 사용한다.
- Reduce Motion 켜짐일 때는 바운스·슬라이드·펄스 없이 최종 포즈로 즉시 전환 후 약 0.4초 대기, 총 0.8초.
- 콜드 스타트에만 노출(웜 스타트 재노출 없음), 워드마크 텍스트 없음, 스킵 제스처 없음, 외부 애니메이션 라이브러리 도입 없음 — spec의 "비목표" 절 그대로.
- 마스코트 지오메트리(색상 hex, 좌표, 반지름 등)는 spec의 "마스코트 지오메트리" 절 값을 정확히 사용해 앱 아이콘과 최종 포즈가 픽셀 단위로 일치해야 한다.
- 테스트 환경(`XCTestConfigurationFilePath` 존재)에서는 스플래시를 완전히 건너뛴다 — 기존 `WadeMoneyApp.init()`의 테스트 호스트 감지와 동일한 패턴, 기존 유닛 테스트 117개와 `WadeMoneyUITests`(`CoreFlowUITests`)가 계속 통과해야 한다.
- 빌드/테스트는 시뮬레이터 `iPhone 17e`로 검증한다(`-destination 'platform=iOS Simulator,name=iPhone 17e'`).
- `xcodegen generate`로 새 파일을 프로젝트에 반영해야 빌드된다(각 태스크의 빌드 스텝 앞에 실행).

---

### Task 1: SplashTimeline + SplashVisibility (순수 로직, UI 없음)

**Files:**
- Create: `WadeMoney/Screens/Splash/SplashTimeline.swift`
- Test: `WadeMoneyTests/SplashTests.swift`

**Interfaces:**
- Produces:
  - `struct SplashTimeline: Equatable` — 필드 `entrance, donutApproach, biteImpact, crumbStagger, hold, exit: TimeInterval`, 계산 프로퍼티 `total: TimeInterval`, 정적 값 `.standard`/`.reduced`, 정적 함수 `static func active(reduceMotion: Bool) -> SplashTimeline`.
  - `enum SplashVisibility` — `static func shouldShowOnLaunch(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool`.

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/SplashTests.swift` 새로 생성:

```swift
import Foundation
import Testing
@testable import WadeMoney

struct SplashTests {
    @Test func standardTimelineTotalsAboutOnePointFourSeconds() {
        let t = SplashTimeline.standard
        #expect(abs(t.total - 1.40) < 0.001)
    }

    @Test func reducedTimelineIsShorterThanStandard() {
        #expect(SplashTimeline.reduced.total < SplashTimeline.standard.total)
    }

    @Test func reducedTimelineSkipsDonutApproachAndBite() {
        let t = SplashTimeline.reduced
        #expect(t.donutApproach == 0)
        #expect(t.biteImpact == 0)
        #expect(t.crumbStagger == 0)
    }

    @Test func activePicksStandardWhenReduceMotionOff() {
        #expect(SplashTimeline.active(reduceMotion: false) == SplashTimeline.standard)
    }

    @Test func activePicksReducedWhenReduceMotionOn() {
        #expect(SplashTimeline.active(reduceMotion: true) == SplashTimeline.reduced)
    }

    @Test func showsSplashWhenNotRunningUnderTestHost() {
        #expect(SplashVisibility.shouldShowOnLaunch(environment: [:]) == true)
    }

    @Test func skipsSplashWhenRunningUnderTestHost() {
        #expect(SplashVisibility.shouldShowOnLaunch(environment: ["XCTestConfigurationFilePath": "/path"]) == false)
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인 (컴파일 실패 예상)**

Run:
```bash
cd /Users/mac/Documents/Projects/WadeMoney
xcodegen generate
xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:WadeMoneyTests/SplashTests 2>&1 | grep -E "error:|BUILD"
```
Expected: `error:` — `Cannot find 'SplashTimeline' in scope` (아직 타입이 없으므로 컴파일 실패).

- [ ] **Step 3: 최소 구현 작성**

`WadeMoney/Screens/Splash/SplashTimeline.swift` 새로 생성:

```swift
import Foundation

/// 스플래시 애니메이션의 각 구간 길이(초). 순수 데이터라 UI 없이 테스트 가능하다.
struct SplashTimeline: Equatable {
    let entrance: TimeInterval
    let donutApproach: TimeInterval
    let biteImpact: TimeInterval
    let crumbStagger: TimeInterval
    let hold: TimeInterval
    let exit: TimeInterval

    var total: TimeInterval {
        entrance + donutApproach + biteImpact + hold + exit
    }

    /// 기본 애니메이션: 등장 → 도넛 접근 → 베어물기 → 정지 → 퇴장, 총 1.4초.
    static let standard = SplashTimeline(
        entrance: 0.35,
        donutApproach: 0.40,
        biteImpact: 0.20,
        crumbStagger: 0.05,
        hold: 0.25,
        exit: 0.20
    )

    /// Reduce Motion용: 슬라이드·바운스 구간을 사실상 0초로 접어 순간적으로 최종 포즈만
    /// 보여주고, 정지 구간만 조금 더 길게(0.4초) 유지한다.
    static let reduced = SplashTimeline(
        entrance: 0.20,
        donutApproach: 0,
        biteImpact: 0,
        crumbStagger: 0,
        hold: 0.40,
        exit: 0.20
    )

    static func active(reduceMotion: Bool) -> SplashTimeline {
        reduceMotion ? .reduced : .standard
    }
}

/// 스플래시를 콜드 스타트에서만 보여줄지 결정한다. XCTest/XCUITest 호스트에서는 항상
/// 건너뛴다 — WadeMoneyApp.init()이 같은 환경변수로 테스트 호스트를 감지하는 것과 동일한 패턴.
enum SplashVisibility {
    static func shouldShowOnLaunch(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        environment["XCTestConfigurationFilePath"] == nil
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run:
```bash
cd /Users/mac/Documents/Projects/WadeMoney
xcodegen generate
xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:WadeMoneyTests/SplashTests 2>&1 | grep -E "Test run|error:|TEST (SUC|FAIL)"
```
Expected: `Test run with 7 tests in 1 suite passed` / `TEST SUCCEEDED`.

- [ ] **Step 5: 커밋**

```bash
cd /Users/mac/Documents/Projects/WadeMoney
git add WadeMoney/Screens/Splash/SplashTimeline.swift WadeMoneyTests/SplashTests.swift
git commit -m "feat(splash): 스플래시 애니메이션 타임라인 + 노출 조건 로직 추가"
```

---

### Task 2: MascotView (벡터 마스코트, 애니메이션 상태 기반 렌더링)

**Files:**
- Create: `WadeMoney/DesignSystem/MascotView.swift`

**Interfaces:**
- Consumes: 없음 (독립적인 View. `Color(hex:)`는 `WadeMoney/DesignSystem/Color+Hex.swift`에 이미 존재하는 것을 사용).
- Produces:
  - `struct MascotAnimationState: Equatable` — 필드 `faceScale, donutOffset: CGSize, donutRotationDegrees: Double, biteMaskProgress: CGFloat, mouthOpenProgress: CGFloat, crumbProgress: [CGFloat]`(3개), 정적 값 `.initial`/`.finalPose`.
  - `struct MascotView: View` — `init(state: MascotAnimationState = .finalPose)`. 200×200pt 고정 캔버스.

- [ ] **Step 1: 구현 작성**

`WadeMoney/DesignSystem/MascotView.swift` 새로 생성:

```swift
import SwiftUI

/// 마스코트(도넛 먹는 돼지)의 애니메이션 가능한 상태. 모든 좌표는 200×200 authoring
/// 캔버스 기준이며, 앱 아이콘(AppIcon.appiconset) 생성에 쓰인 것과 동일한 지오메트리를 공유한다.
struct MascotAnimationState: Equatable {
    /// 돼지 얼굴 그룹 전체 스케일. 1.0이 기본, 베어무는 순간 잠깐 커진다.
    var faceScale: CGFloat = 1.0
    /// 도넛의 최종 위치(캔버스 (158,124))로부터의 오프셋. .zero면 최종 위치.
    var donutOffset: CGSize = .zero
    /// 도넛 회전각(도). 최종값은 -16.
    var donutRotationDegrees: Double = -16
    /// 0=베어물기 전(완전한 원), 1=최종 베어문 자국(반지름 17.5pt) 완성.
    var biteMaskProgress: CGFloat = 1
    /// 0=입 다뭄, 1=씹느라 살짝 벌어짐.
    var mouthOpenProgress: CGFloat = 0
    /// 부스러기 3개 각각의 등장 진행도(0=안 보임, 1=완전히 팝).
    var crumbProgress: [CGFloat] = [0, 0, 0]

    /// 스플래시 시작 시점: 도넛이 화면 위쪽 밖에 있고, 아직 베어물지 않은 완전한 원.
    static let initial = MascotAnimationState(
        faceScale: 0.85,
        donutOffset: CGSize(width: 0, height: -90),
        donutRotationDegrees: -34,
        biteMaskProgress: 0,
        mouthOpenProgress: 0,
        crumbProgress: [0, 0, 0]
    )

    /// 정지 포즈: 앱 아이콘과 픽셀 단위로 동일한 최종 상태(멤버 기본값 그대로).
    static let finalPose = MascotAnimationState()
}

/// 도넛 먹는 돼지 마스코트. 200×200pt 고정 캔버스. 배경은 그리지 않으므로(스플래시가
/// 자체 배경을 깔기 때문) 호출부에서 배경 위에 얹어 쓴다.
struct MascotView: View {
    var state: MascotAnimationState = .finalPose

    var body: some View {
        ZStack {
            pig
            donut
            crumbs
        }
        .frame(width: 200, height: 200)
    }

    private var pig: some View {
        ZStack {
            UnevenRoundedRectangle(topLeadingRadius: 24.84, bottomLeadingRadius: 3.68, bottomTrailingRadius: 23, topTrailingRadius: 24.84)
                .fill(Color(hex: "EA8FA4"))
                .frame(width: 46, height: 46)
                .rotationEffect(.degrees(-22))
                .position(x: 53, y: 59)

            UnevenRoundedRectangle(topLeadingRadius: 24.84, bottomLeadingRadius: 23, bottomTrailingRadius: 3.68, topTrailingRadius: 24.84)
                .fill(Color(hex: "EA8FA4"))
                .frame(width: 46, height: 46)
                .rotationEffect(.degrees(22))
                .position(x: 133, y: 59)

            UnevenRoundedRectangle(topLeadingRadius: 72, bottomLeadingRadius: 61.1, bottomTrailingRadius: 61.1, topTrailingRadius: 72)
                .fill(RadialGradient(colors: [Color(hex: "FAC3CE"), Color(hex: "EE97AB")], center: UnitPoint(x: 0.42, y: 0.30), startRadius: 0, endRadius: 90))
                .frame(width: 144, height: 130)
                .position(x: 93, y: 119)

            eye(center: CGPoint(x: 66.5, y: 100), highlightCenter: CGPoint(x: 64.25, y: 95.75))
            eye(center: CGPoint(x: 116.5, y: 100), highlightCenter: CGPoint(x: 114.25, y: 95.75))

            Ellipse().fill(Color(hex: "E8788C").opacity(0.42)).frame(width: 23, height: 13).position(x: 45.5, y: 124.5)
            Ellipse().fill(Color(hex: "E8788C").opacity(0.42)).frame(width: 23, height: 13).position(x: 140.5, y: 124.5)

            Ellipse()
                .fill(RadialGradient(colors: [Color(hex: "F2AAB8"), Color(hex: "E0899B")], center: UnitPoint(x: 0.42, y: 0.32), startRadius: 0, endRadius: 36))
                .frame(width: 58, height: 40).position(x: 93, y: 138)
            Ellipse().fill(Color(hex: "B0687A")).frame(width: 8, height: 13).position(x: 83.5, y: 138)
            Ellipse().fill(Color(hex: "B0687A")).frame(width: 8, height: 13).position(x: 98.5, y: 138)

            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 13, bottomTrailingRadius: 13, topTrailingRadius: 0)
                .fill(Color(hex: "8A4150")).frame(width: 26, height: 15).position(x: 93, y: 161.5)
            Ellipse()
                .fill(Color(hex: "EE8FA0"))
                .frame(width: 16, height: 10)
                .scaleEffect(x: 1, y: 1 + state.mouthOpenProgress * 0.3, anchor: .top)
                .position(x: 93, y: 168)
        }
        .scaleEffect(state.faceScale)
    }

    private func eye(center: CGPoint, highlightCenter: CGPoint) -> some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [Color(hex: "5B3B44"), Color(hex: "3A252C")], center: UnitPoint(x: 0.38, y: 0.30), startRadius: 0, endRadius: 14))
                .frame(width: 17, height: 20)
                .position(x: center.x, y: center.y)
            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: 5.5, height: 5.5)
                .position(x: highlightCenter.x, y: highlightCenter.y)
        }
    }

    private var donut: some View {
        donutRing
            .frame(width: 72, height: 72)
            .compositingGroup()
            .rotationEffect(.degrees(state.donutRotationDegrees))
            .shadow(color: Color(red: 90.0 / 255, green: 66.0 / 255, blue: 40.0 / 255).opacity(0.24), radius: 6, x: 0, y: 6)
            .position(x: 158 + state.donutOffset.width, y: 124 + state.donutOffset.height)
    }

    private var donutRing: some View {
        let stops: [Gradient.Stop] = [
            .init(color: Color(hex: "3E9E7A"), location: 0.0 / 360),
            .init(color: Color(hex: "3E9E7A"), location: 160.0 / 360),
            .init(color: Color(hex: "FBF6EC"), location: 160.0 / 360),
            .init(color: Color(hex: "FBF6EC"), location: 165.0 / 360),
            .init(color: Color(hex: "E0A93F"), location: 165.0 / 360),
            .init(color: Color(hex: "E0A93F"), location: 244.0 / 360),
            .init(color: Color(hex: "FBF6EC"), location: 244.0 / 360),
            .init(color: Color(hex: "FBF6EC"), location: 249.0 / 360),
            .init(color: Color(hex: "6F9FD8"), location: 249.0 / 360),
            .init(color: Color(hex: "6F9FD8"), location: 300.0 / 360),
            .init(color: Color(hex: "FBF6EC"), location: 300.0 / 360),
            .init(color: Color(hex: "FBF6EC"), location: 305.0 / 360),
            .init(color: Color(hex: "EC8FB6"), location: 305.0 / 360),
            .init(color: Color(hex: "EC8FB6"), location: 355.0 / 360),
            .init(color: Color(hex: "FBF6EC"), location: 355.0 / 360),
            .init(color: Color(hex: "FBF6EC"), location: 360.0 / 360),
        ]
        return ZStack {
            Circle()
                .fill(AngularGradient(gradient: Gradient(stops: stops), center: .center))
                .frame(width: 72, height: 72)
                .position(x: 36, y: 36)

            Circle()
                .fill(Color.black)
                .frame(width: 35 * state.biteMaskProgress, height: 35 * state.biteMaskProgress)
                .position(x: 4, y: 39)
                .blendMode(.destinationOut)

            Circle()
                .fill(LinearGradient(colors: [Color(hex: "FBF6EC"), Color(hex: "F1E6D5")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 30, height: 30)
                .position(x: 36, y: 36)

            Text("\u{20A9}")
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(Color(hex: "2E8E6E"))
                .position(x: 36, y: 36)
        }
    }

    private var crumbs: some View {
        ZStack {
            crumb(color: "3E9E7A", size: 8, rotation: 20, cornerRadius: 2, position: CGPoint(x: 116, y: 136), progress: state.crumbProgress[0])
            crumb(color: "E0A93F", size: 6, rotation: -15, cornerRadius: 2, position: CGPoint(x: 107, y: 147), progress: state.crumbProgress[1])
            crumb(color: "EC8FB6", size: 5, rotation: 0, cornerRadius: 2.5, position: CGPoint(x: 123.5, y: 149.5), progress: state.crumbProgress[2])
        }
    }

    private func crumb(color: String, size: CGFloat, rotation: Double, cornerRadius: CGFloat, position: CGPoint, progress: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(hex: color))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .opacity(progress)
            .position(x: position.x, y: position.y - 6 * progress)
    }
}

#Preview("최종 포즈") {
    MascotView(state: .finalPose)
        .padding(40)
        .background(Color(hex: "F6F0E6"))
}

#Preview("시작 포즈") {
    MascotView(state: .initial)
        .padding(40)
        .background(Color(hex: "F6F0E6"))
}
```

- [ ] **Step 2: 빌드 확인**

Run:
```bash
cd /Users/mac/Documents/Projects/WadeMoney
xcodegen generate
xcodebuild build -project WadeMoney.xcodeproj -scheme WadeMoney \
  -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`, `error:` 없음.

- [ ] **Step 3: 커밋**

```bash
cd /Users/mac/Documents/Projects/WadeMoney
git add WadeMoney/DesignSystem/MascotView.swift
git commit -m "feat(splash): 앱 아이콘과 동일한 벡터 마스코트 View 추가"
```

---

### Task 3: SplashScreen (타임라인 재생 orchestration)

**Files:**
- Create: `WadeMoney/Screens/Splash/SplashScreen.swift`

**Interfaces:**
- Consumes: `SplashTimeline`/`SplashTimeline.active(reduceMotion:)` (Task 1), `MascotAnimationState`/`.initial`/`MascotView` (Task 2), `WadeColors.bg(_:)`(기존 `WadeMoney/DesignSystem/WadeColors.swift`).
- Produces: `struct SplashScreen: View` — `init(onFinished: @escaping () -> Void)`.

- [ ] **Step 1: 구현 작성**

`WadeMoney/Screens/Splash/SplashScreen.swift` 새로 생성:

```swift
import SwiftUI

/// 콜드 스타트 시 짧게 보여주는 스플래시. 마스코트가 도넛을 베어무는 모션을 재생한 뒤
/// onFinished()를 호출해 RootView가 메인 화면으로 전환하도록 한다.
///
/// Reduce Motion이 켜져 있으면 SplashTimeline.reduced의 구간별 길이가 0에 가까워
/// (donutApproach/biteImpact/crumbStagger = 0) 슬라이드·바운스가 사실상 즉시 끝나고
/// 최종 포즈만 짧게 보여준 뒤 넘어간다 — 별도 분기 없이 같은 코드 경로로 처리한다.
struct SplashScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mascotState: MascotAnimationState = .initial
    @State private var opacity: Double = 1
    let onFinished: () -> Void

    var body: some View {
        WadeColors.bg(scheme)
            .ignoresSafeArea()
            .overlay {
                MascotView(state: mascotState)
            }
            .opacity(opacity)
            .task { await runTimeline() }
    }

    private func runTimeline() async {
        let timeline = SplashTimeline.active(reduceMotion: reduceMotion)

        withAnimation(.easeOut(duration: max(timeline.entrance, 0.001))) {
            mascotState.faceScale = 1.0
        }
        try? await Task.sleep(for: .seconds(timeline.entrance))

        withAnimation(.easeOut(duration: max(timeline.donutApproach, 0.001))) {
            mascotState.donutOffset = .zero
            mascotState.donutRotationDegrees = -16
        }
        try? await Task.sleep(for: .seconds(timeline.donutApproach))

        withAnimation(.spring(response: max(timeline.biteImpact, 0.001), dampingFraction: 0.6)) {
            mascotState.biteMaskProgress = 1
            mascotState.faceScale = 1.04
            mascotState.mouthOpenProgress = 1
        }
        for index in mascotState.crumbProgress.indices {
            let delay = Double(index) * timeline.crumbStagger
            Task {
                try? await Task.sleep(for: .seconds(delay))
                withAnimation(.easeOut(duration: max(timeline.biteImpact * 0.6, 0.001))) {
                    mascotState.crumbProgress[index] = 1
                }
            }
        }
        try? await Task.sleep(for: .seconds(timeline.biteImpact))

        withAnimation(.easeInOut(duration: max(timeline.biteImpact * 0.75, 0.001))) {
            mascotState.faceScale = 1.0
            mascotState.mouthOpenProgress = 0
            mascotState.crumbProgress = [0, 0, 0]
        }
        try? await Task.sleep(for: .seconds(timeline.hold))

        withAnimation(.easeInOut(duration: max(timeline.exit, 0.001))) {
            opacity = 0
        }
        try? await Task.sleep(for: .seconds(timeline.exit))

        onFinished()
    }
}

#Preview {
    SplashScreen(onFinished: {})
}
```

- [ ] **Step 2: 빌드 확인**

Run:
```bash
cd /Users/mac/Documents/Projects/WadeMoney
xcodegen generate
xcodebuild build -project WadeMoney.xcodeproj -scheme WadeMoney \
  -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: 커밋**

```bash
cd /Users/mac/Documents/Projects/WadeMoney
git add WadeMoney/Screens/Splash/SplashScreen.swift
git commit -m "feat(splash): 애니메이션 타임라인을 재생하는 SplashScreen 추가"
```

---

### Task 4: RootView 통합 + 전체 검증

**Files:**
- Modify: `WadeMoney/RootView.swift` (전체 내용 교체)

**Interfaces:**
- Consumes: `SplashVisibility.shouldShowOnLaunch()` (Task 1), `SplashScreen` (Task 3).
- Produces: 없음 (최상위 통합 지점).

- [ ] **Step 1: RootView 수정**

`WadeMoney/RootView.swift` 전체를 아래로 교체:

```swift
import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var settingsModels: [AppSettingsModel]
    @State private var showSplash = SplashVisibility.shouldShowOnLaunch()

    /// 여러 기기의 CloudKit 병합으로 설정 행이 잠깐 중복될 수 있다 — SettingsStore와 동일하게
    /// id 최솟값 행을 결정적으로 채택한다(둘 다 같은 규칙이어야 기기 간 동일하게 보인다).
    private var appearance: AppAppearance {
        let winner = settingsModels.min { $0.id < $1.id }
        return AppAppearance(rawValue: winner?.appearanceRaw ?? 0) ?? .system
    }

    var body: some View {
        ZStack {
            RootTabView()
            if showSplash {
                SplashScreen(onFinished: { showSplash = false })
            }
        }
        .preferredColorScheme(appearance.colorScheme)
    }
}

#Preview {
    RootView()
}
```

- [ ] **Step 2: 프로젝트 재생성 + 전체 빌드**

Run:
```bash
cd /Users/mac/Documents/Projects/WadeMoney
xcodegen generate
xcodebuild build -project WadeMoney.xcodeproj -scheme WadeMoney \
  -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: 기존 유닛 테스트 전체 통과 확인 (117개 + Task 1의 SplashTests 7개 = 124개)**

Run:
```bash
cd /Users/mac/Documents/Projects/WadeMoney
xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:WadeMoneyTests 2>&1 | grep -E "Test run|error:|TEST (SUC|FAIL)"
```
Expected: `Test run with 124 tests in 32 suites passed` / `TEST SUCCEEDED`.

- [ ] **Step 4: 기존 E2E 테스트가 스플래시에 막히지 않는지 확인**

Run:
```bash
cd /Users/mac/Documents/Projects/WadeMoney
xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoneyUITests \
  -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "Test Case|error:|TEST (SUC|FAIL)"
```
Expected: `CoreFlowUITests`의 두 테스트 모두 `passed`. (RootView가 `XCTestConfigurationFilePath` 환경변수를 감지해 `showSplash`를 처음부터 `false`로 초기화하므로 "한눈에" 텍스트를 곧장 기다릴 수 있어야 한다.)

- [ ] **Step 5: 시뮬레이터에서 육안 확인 (라이트 모드)**

Run:
```bash
cd /Users/mac/Documents/Projects/WadeMoney
xcrun simctl boot "iPhone 17e" 2>&1 || true
APP=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 5 -type d -name "WadeMoney.app" -path "*Debug-iphonesimulator*" 2>/dev/null | head -1)
echo "APP=$APP"
xcrun simctl install "iPhone 17e" "$APP"
xcrun simctl terminate "iPhone 17e" com.kimhyeongi.WadeMoney 2>&1 || true
xcrun simctl launch "iPhone 17e" com.kimhyeongi.WadeMoney
sleep 0.5
xcrun simctl io "iPhone 17e" screenshot /tmp/splash-light-mid.png
sleep 1
xcrun simctl io "iPhone 17e" screenshot /tmp/splash-light-end.png
```
Expected: 첫 스크린샷(0.5초 시점)에 도넛이 아직 접근 중이거나 막 베어문 상태, 두 번째(1.5초 시점)에는 이미 대시보드("한눈에")로 전환되어 있어야 한다. `Read` 도구로 두 PNG를 열어 실제로 마스코트가 그려지는지, 라이트 배경(`WadeColors.bg`)이 적용되는지 확인한다.

- [ ] **Step 6: 다크 모드 확인**

설정 > 화면 모드를 "다크"로 바꾼 뒤 앱을 완전히 종료(`xcrun simctl terminate`)했다가 다시 실행해 Step 5와 동일하게 스크린샷을 찍는다. 배경이 `WadeColors.bg` 다크 값으로 바뀌는지 확인한다.

- [ ] **Step 7: Reduce Motion 확인**

Run:
```bash
xcrun simctl spawn "iPhone 17e" defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
```
앱을 완전히 종료 후 재실행해 스크린샷을 찍는다. 슬라이드/바운스 없이 최종 포즈가 거의 즉시 나타났다가 대시보드로 넘어가는지 확인한다. 확인 후 원복:
```bash
xcrun simctl spawn "iPhone 17e" defaults write com.apple.Accessibility ReduceMotionEnabled -bool false
```

- [ ] **Step 8: 커밋**

```bash
cd /Users/mac/Documents/Projects/WadeMoney
git add WadeMoney/RootView.swift
git commit -m "feat(splash): RootView에 콜드 스타트 스플래시 연결"
```

---

## Post-Plan Verification

전체 태스크 완료 후:

```bash
cd /Users/mac/Documents/Projects/WadeMoney
xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney \
  -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:WadeMoneyTests 2>&1 | tail -5
xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoneyUITests \
  -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | tail -10
git log --oneline -5
```

모두 통과하면 사용자에게 결과를 보고하고 푸시 여부를 확인한다(이 세션의 기존 관례상 커밋까지는 자동, 푸시는 명시적 요청 시에만).
