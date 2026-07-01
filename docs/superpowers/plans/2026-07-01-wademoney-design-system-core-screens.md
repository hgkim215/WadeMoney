# WadeMoney — 디자인 시스템 + 핵심 화면 Implementation Plan (3/6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 디자인 시스템 토대(폰트·컬러·타이포·아이콘·형태 토큰 + 공통 포매팅)를 세우고, 앱의 핵심 루프인 **대시보드("한눈에")**와 **빠른 입력 시트**를 구현해 "지출 입력 → 대시보드 즉시 반영"이 실제 동작하게 한다.

**Architecture:** 순수 변환 로직은 `@Observable` 뷰모델에 두어 단위 테스트하고(리포지토리 + 주입된 `now`/`calendar`로 표시용 값 산출), SwiftUI 뷰는 그 뷰모델을 렌더한다. 디자인 토큰은 [디자인 시스템 문서](../specs/2026-07-01-wademoney-design-system.md)의 값을 코드 상수로 옮긴다. 아이콘은 번들된 Material Symbols Rounded 폰트의 리거처로, 한글은 Pretendard로 렌더한다.

**Tech Stack:** SwiftUI, `@Observable`(Observation), SwiftData(기존 `LedgerRepository`/`SettingsStore`), `WadeMoneyCore`, Swift Testing, XcodeGen, iOS 26 시뮬레이터.

## Global Constraints

- **범위**: 이 계획은 **디자인 시스템 + 대시보드 + 빠른 입력**만. 내역·설정·카테고리 관리·AI 리포트 화면은 **계획 4**. AI 실제 생성은 이후 계획(대시보드 AI 카드는 이 계획에선 데이터 없으면 숨김).
- **토큰 출처**: 색·타이포·radius·spacing·shadow 값은 디자인 시스템 문서 §1~§3을 그대로 사용(라이트/다크 2벌). 임의 색·크기 금지.
- **폰트**: Pretendard Variable(한글 본문) + Material Symbols Rounded(아이콘) 번들. 아이콘은 카테고리 `iconName`(예: `local_cafe`)을 **리거처**로 렌더.
- **통화**: 원화 정수 표시. `₩` + 천단위 콤마, 소수점 없음. 포매팅은 전용 헬퍼 한 곳(`Won`)에서만.
- **뷰모델 순수성**: 뷰모델은 `now: Date`·`calendar: Calendar`를 주입받아 엔진/리포지토리를 호출한다. 뷰모델·뷰에 `Date()`/`Calendar.current` 직접 호출 금지(주입은 화면 진입점의 프로덕션 기본값에서만: `now = Date()`, `calendar = .current`).
- **페이스 색**: 더 씀 → `bad`(빨강 ▲), 덜 씀 → `good`(초록 ▼). 비교 불가 → "비교할 이전 기록이 없어요".
- **도넛**: `maxSlices: 6`(상위 5개 + 기타). `isOther` 슬라이스는 이름 "기타", 중립색(`ink3` 계열).
- **빌드/테스트**(서명 없이): 루트에서 `xcodegen generate` → `xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
- **화면 수동 검증**: 뷰 태스크는 빌드 통과 + 시뮬레이터 스크린샷으로 확인한다(픽셀은 자동 테스트 대상 아님). 스크린샷: `xcrun simctl` 부팅 → 앱 설치·실행 → `xcrun simctl io booted screenshot <path>`.
- `.build/`·`*.xcodeproj`·`DerivedData/` 추적 금지. 폰트 바이너리는 `WadeMoney/Resources/Fonts/`에 커밋(OFL 라이선스, 허용).

---

### Task 1: 폰트 번들 (Pretendard + Material Symbols Rounded) + 등록

**Files:**
- Create: `WadeMoney/Resources/Fonts/PretendardVariable.ttf` (다운로드)
- Create: `WadeMoney/Resources/Fonts/MaterialSymbolsRounded.ttf` (다운로드)
- Create: `WadeMoney/Info.plist`
- Modify: `project.yml` (app 타깃: `GENERATE_INFOPLIST_FILE` 제거, 명시적 `Info.plist` 사용, 폰트 리소스 포함)
- Test: `WadeMoneyTests/FontRegistrationTests.swift`

**Interfaces:**
- Produces: 번들에 등록된 두 폰트 패밀리. `UIFont(name:size:)`로 로드 가능.

- [ ] **Step 1: 폰트 다운로드**

```bash
cd /Users/mac/Documents/Projects/WadeMoney
mkdir -p WadeMoney/Resources/Fonts
# Pretendard Variable (OFL) — 실패 시 https://github.com/orioncactus/pretendard/releases 최신 자산에서 PretendardVariable.ttf 확보
curl -L -o /tmp/pretendard.zip "https://github.com/orioncactus/pretendard/releases/download/v1.3.9/Pretendard-1.3.9.zip"
unzip -o -j /tmp/pretendard.zip "Pretendard-1.3.9/public/variable/PretendardVariable.ttf" -d WadeMoney/Resources/Fonts/
# Material Symbols Rounded variable font (Apache-2.0/OFL) — 실패 시 google/material-design-icons 저장소 variablefont 폴더에서 확보
curl -L -o WadeMoney/Resources/Fonts/MaterialSymbolsRounded.ttf \
  "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
# 검증: 두 파일이 존재하고 0바이트가 아님
ls -la WadeMoney/Resources/Fonts/
```
두 파일이 받아졌는지 확인(각 수백 KB~수 MB). 받은 TTF의 실제 PostScript 이름을 확인:
```bash
python3 - <<'PY'
from pathlib import Path
for p in Path("WadeMoney/Resources/Fonts").glob("*.ttf"):
    data = p.read_bytes()
    print(p.name, len(data), "bytes")
PY
```
> 실제 등록에 쓸 **PostScript 이름**은 다음 스텝의 테스트로 확정한다(파일명이 아니라 폰트 내부 이름을 써야 함).

- [ ] **Step 2: 폰트 PostScript 이름 확인용 임시 테스트 작성 → 실행해 이름 확보**

`WadeMoneyTests/FontRegistrationTests.swift`:

```swift
import Foundation
import CoreText
import Testing
@testable import WadeMoney

struct FontRegistrationTests {
    /// 번들에 포함된 두 폰트가 로드되는지 확인.
    @Test func bundledFontsAreRegistered() {
        // Pretendard: 가변 폰트의 PostScript 이름
        #expect(FontNames.pretendard != nil)
        // Material Symbols Rounded
        #expect(FontNames.materialSymbols != nil)
    }
}

enum FontNames {
    static let pretendard = resolvedName(containing: "Pretendard")
    static let materialSymbols = resolvedName(containing: "MaterialSymbols")

    private static func resolvedName(containing needle: String) -> String? {
        for family in UIFont.familyNames {
            for name in UIFont.fontNames(forFamilyName: family) where name.contains(needle) {
                return name
            }
        }
        return nil
    }
}
```

`import UIKit` 필요 — 상단 import에 `import UIKit` 추가.

- [ ] **Step 3: 명시적 Info.plist + project.yml 수정 후 RED 확인**

`WadeMoney/Info.plist` 생성(런치스크린·방향·표시명·폰트 등록 포함):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>WadeMoney</string>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
    <key>UIAppFonts</key>
    <array>
        <string>PretendardVariable.ttf</string>
        <string>MaterialSymbolsRounded.ttf</string>
    </array>
</dict>
</plist>
```

`project.yml`의 `WadeMoney` 타깃 `settings.base`에서 `GENERATE_INFOPLIST_FILE: "YES"`와 `INFOPLIST_KEY_*` 라인들을 제거하고, 대신 명시적 plist를 지정한다. 타깃 블록을 다음으로 교체:

```yaml
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
        INFOPLIST_FILE: WadeMoney/Info.plist
        INFOPLIST_KEY_UIBackgroundModes: remote-notification
        TARGETED_DEVICE_FAMILY: "1"
```

`WadeMoney/Resources/`는 `sources: [WadeMoney]`에 포함되므로 폰트가 리소스로 번들된다. 루트 `.gitignore`가 `*.ttf`를 막지 않는지 확인(막으면 `!WadeMoney/Resources/Fonts/*.ttf` 예외 추가).

RED 실행:
```bash
xcodegen generate
xcodebuild test -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO 2>&1 | tail -20
```
Expected: `FontRegistrationTests` 통과(폰트가 실제로 로드되면 이미 GREEN일 수 있음). 만약 `FontNames.*`가 nil이면 Info.plist의 파일명·번들 포함 여부를 점검해 통과시킨다.

- [ ] **Step 4: 통과 확인 + 커밋**

전체 스위트 GREEN(기존 18 + FontRegistration 1). 커밋:
```bash
git add WadeMoney/Resources/Fonts WadeMoney/Info.plist project.yml WadeMoneyTests/FontRegistrationTests.swift .gitignore
git commit -m "feat(ui): bundle Pretendard + Material Symbols Rounded fonts"
```

> 참고: 폰트 PostScript 이름(예: Pretendard는 대개 `PretendardVariable`, Material Symbols는 `MaterialSymbolsRounded-Regular` 등)은 Task 3의 폰트 헬퍼에서 필요하다. `FontNames.pretendard`/`.materialSymbols`가 반환한 실제 문자열을 Task 3 구현 시 사용한다.

---

### Task 2: 컬러 토큰 (hex 파서 + 라이트/다크 시맨틱 색)

**Files:**
- Create: `WadeMoney/DesignSystem/Color+Hex.swift`
- Create: `WadeMoney/DesignSystem/WadeColors.swift`
- Test: `WadeMoneyTests/ColorHexTests.swift`

**Interfaces:**
- Produces:
  - `extension Color { init(hex: String) }`
  - `enum WadeColors { static func ... }` — 디자인 시스템 §1 토큰을 라이트/다크로 반환하는 시맨틱 색. 각 토큰은 `Color`를 반환하되 `@Environment(\.colorScheme)`에 따라 뷰에서 선택하도록 라이트/다크 쌍을 노출: `static func bg(_ scheme: ColorScheme) -> Color` 형태.
  - 토큰: `stage, bg, card, card2, ink, ink2, ink3, line, primary, primarysoft, primaryglow, track, barmuted, good, goodsoft, bad, badsoft, shadow, sheet, aitint1, aitint2, toastbg, toastfg`.

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/ColorHexTests.swift`:

```swift
import SwiftUI
import Testing
@testable import WadeMoney

struct ColorHexTests {
    @Test func parsesSixDigitHex() {
        // #3E9E7A → (62,158,122)
        let c = Color(hex: "#3E9E7A")
        let rgb = c.rgbaComponents()
        #expect(abs(rgb.r - 62.0/255) < 0.01)
        #expect(abs(rgb.g - 158.0/255) < 0.01)
        #expect(abs(rgb.b - 122.0/255) < 0.01)
    }

    @Test func parsesWithoutHashPrefix() {
        let c = Color(hex: "FFFFFF")
        let rgb = c.rgbaComponents()
        #expect(rgb.r > 0.99 && rgb.g > 0.99 && rgb.b > 0.99)
    }

    @Test func lightAndDarkTokensDiffer() {
        #expect(WadeColors.primary(.light) != WadeColors.primary(.dark))
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ... CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
Expected: 컴파일 실패 — `Color(hex:)`/`rgbaComponents`/`WadeColors` 없음.

- [ ] **Step 3: hex 파서 구현**

`WadeMoney/DesignSystem/Color+Hex.swift`:

```swift
import SwiftUI
import UIKit

extension Color {
    /// "#RRGGBB" 또는 "RRGGBB"에서 색 생성.
    init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self = Color(red: r, green: g, blue: b)
    }

    /// 테스트용 RGBA 성분(0...1).
    func rgbaComponents() -> (r: Double, g: Double, b: Double, a: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}
```

- [ ] **Step 4: 시맨틱 색 토큰 구현 (디자인 시스템 §1)**

`WadeMoney/DesignSystem/WadeColors.swift`:

```swift
import SwiftUI

enum WadeColors {
    private static func pick(_ scheme: ColorScheme, light: String, dark: String) -> Color {
        Color(hex: scheme == .dark ? dark : light)
    }

    static func stage(_ s: ColorScheme) -> Color { pick(s, light: "#EBE1D2", dark: "#0E0C0B") }
    static func bg(_ s: ColorScheme) -> Color { pick(s, light: "#F6F0E6", dark: "#161311") }
    static func card(_ s: ColorScheme) -> Color { pick(s, light: "#FFFFFF", dark: "#221D19") }
    static func card2(_ s: ColorScheme) -> Color { pick(s, light: "#F6F0E7", dark: "#2A241E") }
    static func ink(_ s: ColorScheme) -> Color { pick(s, light: "#2E2A25", dark: "#F3ECE3") }
    static func ink2(_ s: ColorScheme) -> Color { pick(s, light: "#6C6358", dark: "#B0A498") }
    static func ink3(_ s: ColorScheme) -> Color { pick(s, light: "#7F7466", dark: "#9A8E7F") }
    static func line(_ s: ColorScheme) -> Color { pick(s, light: "#EFE7DB", dark: "#332B24") }
    static func primary(_ s: ColorScheme) -> Color { pick(s, light: "#3E9E7A", dark: "#4DB48C") }
    static func primarysoft(_ s: ColorScheme) -> Color { pick(s, light: "#DFF0E9", dark: "#15251E") }
    static func track(_ s: ColorScheme) -> Color { pick(s, light: "#EDE4D7", dark: "#2E2820") }
    static func barmuted(_ s: ColorScheme) -> Color { pick(s, light: "#F2CBB9", dark: "#5A392C") }
    static func good(_ s: ColorScheme) -> Color { pick(s, light: "#4E9E6A", dark: "#5FB07E") }
    static func goodsoft(_ s: ColorScheme) -> Color { pick(s, light: "#E4F0E7", dark: "#22302A") }
    static func bad(_ s: ColorScheme) -> Color { pick(s, light: "#DB5B45", dark: "#EC7962") }
    static func badsoft(_ s: ColorScheme) -> Color { pick(s, light: "#FBE3DE", dark: "#3A2420") }
    static func sheet(_ s: ColorScheme) -> Color { pick(s, light: "#FFFFFF", dark: "#221D19") }
    static func aitint1(_ s: ColorScheme) -> Color { pick(s, light: "#EFF7F2", dark: "#17251F") }
    static func aitint2(_ s: ColorScheme) -> Color { pick(s, light: "#DFF0E9", dark: "#1E332B") }
    static func toastbg(_ s: ColorScheme) -> Color { pick(s, light: "#2E2A25", dark: "#F3ECE3") }
    static func toastfg(_ s: ColorScheme) -> Color { pick(s, light: "#FFFFFF", dark: "#221D19") }
    static func shadow(_ s: ColorScheme) -> Color { Color.black.opacity(s == .dark ? 0.4 : 0.10) }
}
```

- [ ] **Step 5: 통과 확인 + 커밋**

전체 GREEN. 커밋:
```bash
git add WadeMoney/DesignSystem WadeMoneyTests/ColorHexTests.swift
git commit -m "feat(ui): add hex color parser and WadeColors semantic tokens"
```

---

### Task 3: 타이포·아이콘·형태 토큰

**Files:**
- Create: `WadeMoney/DesignSystem/WadeFont.swift`
- Create: `WadeMoney/DesignSystem/IconView.swift`
- Create: `WadeMoney/DesignSystem/WadeMetrics.swift`
- Test: `WadeMoneyTests/DesignTokenTests.swift`

**Interfaces:**
- Produces:
  - `enum WadeFont { static func pretendard(_ size: CGFloat, weight: Font.Weight) -> Font }`
  - `struct Icon: View { init(_ name: String, size: CGFloat, filled: Bool) }` — Material Symbols 리거처 렌더
  - `enum WadeRadius { static let card: CGFloat = 24; ... }`, `enum WadeSpacing`, `struct WadeShadow`
  - `enum FontFamily { static let pretendard: String; static let materialSymbols: String }` — Task 1에서 확인한 PostScript 이름

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/DesignTokenTests.swift`:

```swift
import SwiftUI
import UIKit
import Testing
@testable import WadeMoney

struct DesignTokenTests {
    @Test func fontFamilyNamesResolveToRegisteredFonts() {
        // Task 1에서 확인한 이름이 실제 UIFont로 로드돼야 함
        #expect(UIFont(name: FontFamily.pretendard, size: 14) != nil)
        #expect(UIFont(name: FontFamily.materialSymbols, size: 20) != nil)
    }

    @Test func radiusTokensMatchDesignSystem() {
        #expect(WadeRadius.card == 24)
        #expect(WadeRadius.listCard == 20)
        #expect(WadeRadius.pill == 999)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ...`
Expected: 컴파일 실패 — `FontFamily`/`WadeRadius` 없음.

- [ ] **Step 3: 형태 토큰 구현**

`WadeMoney/DesignSystem/WadeMetrics.swift`:

```swift
import SwiftUI

enum WadeRadius {
    static let card: CGFloat = 24
    static let listCard: CGFloat = 20
    static let control: CGFloat = 16
    static let segment: CGFloat = 14
    static let iconTile: CGFloat = 12
    static let pill: CGFloat = 999
    static let sheet: CGFloat = 30
    static let fab: CGFloat = 20
}

enum WadeSpacing {
    static let screenH: CGFloat = 18
    static let cardGap: CGFloat = 14
    static let cardPadding: CGFloat = 20
    static let contentTop: CGFloat = 60
    static let contentBottom: CGFloat = 104
}

struct WadeShadow {
    static func card(_ scheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
        (WadeColors.shadow(scheme), 26, 10)
    }
    static func list(_ scheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
        (WadeColors.shadow(scheme), 22, 8)
    }
}
```

- [ ] **Step 4: 폰트·아이콘 구현**

`WadeMoney/DesignSystem/WadeFont.swift` — `FontFamily`의 문자열은 Task 1 `FontNames`가 반환한 실제 PostScript 이름으로 채운다(예시값은 확인 후 교체):

```swift
import SwiftUI

enum FontFamily {
    /// Task 1의 FontRegistrationTests가 확인한 실제 PostScript 이름으로 설정.
    static let pretendard = "PretendardVariable"
    static let materialSymbols = "MaterialSymbolsRounded-Regular"
}

enum WadeFont {
    static func pretendard(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(FontFamily.pretendard, size: size).weight(weight)
    }
}
```

`WadeMoney/DesignSystem/IconView.swift`:

```swift
import SwiftUI

/// Material Symbols Rounded 리거처로 아이콘을 렌더. `name`은 심볼 이름(예: "local_cafe").
struct Icon: View {
    let name: String
    var size: CGFloat = 20
    var filled: Bool = true

    var body: some View {
        Text(name)
            .font(.custom(FontFamily.materialSymbols, size: size))
            .fontVariation(fill: filled)
    }
}

private extension View {
    /// FILL 축 적용(가변 폰트). 미지원 시 무해하게 무시됨.
    func fontVariation(fill: Bool) -> some View {
        // Material Symbols FILL 축: 0(외곽선)~1(채움). SwiftUI Font의 variation은
        // iOS 26에서 .fontWidth 등 제한적이므로, 채움 여부는 폰트 기본(Regular=외곽선)을 쓰고
        // 채운 스타일이 필요하면 Rounded의 Filled 변형 이름을 FontFamily에 별도 추가한다.
        self
    }
}
```

> 주: Material Symbols의 FILL 축을 SwiftUI에서 세밀 제어하기 어렵다. 이 계획은 **채움(FILL 1)**을 기본 표현으로 삼되, 가변축 제어가 안 되면 Task 3에서 채워진 정적 변형 폰트를 추가하거나 외곽선으로 렌더하고, 정확한 채움은 후속 폴리시로 넘긴다(디자인 시스템 §9 범위). 아이콘이 **모양대로 보이는지**를 스크린샷으로 확인한다.

- [ ] **Step 5: 통과 확인 + 커밋**

`DesignTokenTests` 통과(폰트 이름이 실제로 로드). 실패하면 `FontFamily`의 문자열을 Task 1이 확인한 이름으로 교정. 커밋:
```bash
git add WadeMoney/DesignSystem/WadeFont.swift WadeMoney/DesignSystem/IconView.swift WadeMoney/DesignSystem/WadeMetrics.swift WadeMoneyTests/DesignTokenTests.swift
git commit -m "feat(ui): add typography, icon, and shape tokens"
```

---

### Task 4: 포매팅 헬퍼 (통화 + 기간 라벨)

**Files:**
- Create: `WadeMoney/Formatting/Won.swift`
- Create: `WadeMoney/Formatting/PeriodLabel.swift`
- Test: `WadeMoneyTests/FormattingTests.swift`

**Interfaces:**
- Produces:
  - `enum Won { static func string(_ amount: Decimal) -> String }` — 천단위 콤마, 소수 없음(예: `1300000` → `"1,300,000"`).
  - `enum PeriodLabel { static func text(kind: PeriodKind, period: Period, now: Date, calendar: Calendar) -> String }` — 일: `"7월 15일"`(+오늘이면 `" (오늘)"`), 월: `"2026년 7월"`, 연: `"2026년"`.

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/FormattingTests.swift`:

```swift
import Foundation
import Testing
import WadeMoneyCore
@testable import WadeMoney

struct FormattingTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }

    @Test func wonAddsThousandsSeparators() {
        #expect(Won.string(1_300_000) == "1,300,000")
        #expect(Won.string(0) == "0")
        #expect(Won.string(840_000) == "840,000")
    }

    @Test func monthLabel() {
        let calc = PeriodCalculator(calendar: utc, monthStartDay: 1)
        let p = calc.period(.month, containing: date(2026, 7, 15))
        #expect(PeriodLabel.text(kind: .month, period: p, now: date(2026, 7, 15), calendar: utc) == "2026년 7월")
    }

    @Test func dayLabelMarksToday() {
        let calc = PeriodCalculator(calendar: utc, monthStartDay: 1)
        let p = calc.period(.day, containing: date(2026, 7, 15))
        #expect(PeriodLabel.text(kind: .day, period: p, now: date(2026, 7, 15), calendar: utc) == "7월 15일 (오늘)")
        // 다른 날이면 (오늘) 없음
        let p2 = calc.period(.day, containing: date(2026, 7, 10))
        #expect(PeriodLabel.text(kind: .day, period: p2, now: date(2026, 7, 15), calendar: utc) == "7월 10일")
    }

    @Test func yearLabel() {
        let calc = PeriodCalculator(calendar: utc, monthStartDay: 1)
        let p = calc.period(.year, containing: date(2026, 7, 15))
        #expect(PeriodLabel.text(kind: .year, period: p, now: date(2026, 7, 15), calendar: utc) == "2026년")
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ...`
Expected: 컴파일 실패 — `Won`/`PeriodLabel` 없음.

- [ ] **Step 3: 구현 작성**

`WadeMoney/Formatting/Won.swift`:

```swift
import Foundation

enum Won {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.locale = Locale(identifier: "ko_KR")
        return f
    }()

    static func string(_ amount: Decimal) -> String {
        formatter.string(from: amount as NSDecimalNumber) ?? "0"
    }
}
```

`WadeMoney/Formatting/PeriodLabel.swift`:

```swift
import Foundation
import WadeMoneyCore

enum PeriodLabel {
    static func text(kind: PeriodKind, period: Period, now: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: period.start)
        switch kind {
        case .day:
            let today = calendar.isDate(period.start, inSameDayAs: now)
            return "\(c.month ?? 0)월 \(c.day ?? 0)일" + (today ? " (오늘)" : "")
        case .month:
            return "\(c.year ?? 0)년 \(c.month ?? 0)월"
        case .year:
            return "\(c.year ?? 0)년"
        }
    }
}
```

- [ ] **Step 4: 통과 확인 + 커밋**

전체 GREEN. 커밋:
```bash
git add WadeMoney/Formatting WadeMoneyTests/FormattingTests.swift
git commit -m "feat(ui): add Won currency and PeriodLabel formatters"
```

---

### Task 5: `DashboardViewModel` (표시 모델 조립)

리포지토리의 `DashboardSummary`를 화면이 바로 그릴 수 있는 표시 모델로 변환한다(포매팅·페이스 배지·도넛 범례 조인·추세 막대).

**Files:**
- Create: `WadeMoney/Screens/Dashboard/DashboardViewModel.swift`
- Test: `WadeMoneyTests/DashboardViewModelTests.swift`

**Interfaces:**
- Consumes: `LedgerRepository`, `WadeMoneyCore`(`PeriodKind`, `PaceResult`, `DonutSlice`), `Won`, `PeriodLabel`
- Produces:
  - `@Observable final class DashboardViewModel` (`@MainActor`), init(`repository: LedgerRepository`, `now: Date`, `calendar: Calendar`)
  - `var kind: PeriodKind`, `var offset: Int`, `func load()`
  - `struct DashboardDisplay { periodLabel; totalText; scopeText; budgetText; remainText; consumedPercentText; consumedFraction; pace: PaceBadge?; dayBudget: DayBudgetInfo?; donut: [DonutLegendItem]; trend: [TrendBar] }`
  - `struct PaceBadge { deltaText: String; direction: enum {up, down}; note: String }` / `struct DonutLegendItem { name; colorHex; percentText; isOther; categoryID: UUID? }` / `struct TrendBar { label; heightFraction; isCurrent }`
  - `var display: DashboardDisplay?`

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/DashboardViewModelTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct DashboardViewModelTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }

    /// 컨테이너를 보유(SwiftData dealloc 방지)한 채 시드된 리포지토리 반환.
    func makeRepo() throws -> (LedgerRepository, SettingsStore, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        let ctx = container.mainContext
        try CategorySeeder.seedIfNeeded(ctx)
        return (LedgerRepository(context: ctx), SettingsStore(context: ctx), container)
    }
    func catID(_ repo: LedgerRepository, _ name: String) throws -> UUID {
        try repo.allCategories(includeArchived: false).first { $0.name == name }!.id
    }

    @Test func buildsMonthDisplayWithPaceAndDonut() throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(1_000_000, for: YearMonth(year: 2026, month: 7))
        let food = try catID(repo, "식비"); let cafe = try catID(repo, "카페")
        try repo.addTransaction(amount: 100_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 5))
        try repo.addTransaction(amount: 60_000, type: .expense, categoryID: cafe, memo: nil, date: date(2026, 7, 6))

        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc)
        vm.kind = .month
        vm.load()

        let d = try #require(vm.display)
        #expect(d.periodLabel == "2026년 7월")
        #expect(d.totalText == "160,000")
        #expect(d.budgetText == "1,000,000")
        #expect(d.remainText == "840,000")
        #expect(d.donut.count == 2)
        #expect(d.donut.first?.name == "식비")     // 최대 먼저
        #expect(d.pace != nil)                      // 월 뷰는 페이스 있음
        _ = container
    }

    @Test func dayViewHasNoPaceButHasDayBudget() throws {
        let (repo, settings, container) = try makeRepo()
        try settings.setMonthlyBudget(310_000, for: YearMonth(year: 2026, month: 7)) // 31일 → 일예산 10,000
        let food = try catID(repo, "식비")
        try repo.addTransaction(amount: 3_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 15))

        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc)
        vm.kind = .day
        vm.load()

        let d = try #require(vm.display)
        #expect(d.pace == nil)
        #expect(d.dayBudget != nil)
        _ = container
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ...`
Expected: 컴파일 실패 — `DashboardViewModel` 없음.

- [ ] **Step 3: 뷰모델 구현**

`WadeMoney/Screens/Dashboard/DashboardViewModel.swift`:

```swift
import Foundation
import Observation
import WadeMoneyCore

@MainActor
@Observable
final class DashboardViewModel {
    enum PaceDirection { case up, down }

    struct PaceBadge: Equatable {
        let deltaText: String       // 예: "12%"
        let direction: PaceDirection
        let note: String            // 예: "지난달 같은 시점보다"
    }
    struct DayBudgetInfo: Equatable {
        let dayBudgetText: String
        let remainText: String
    }
    struct DonutLegendItem: Equatable, Identifiable {
        let id: String
        let categoryID: UUID?
        let name: String
        let colorHex: String
        let percentText: String
        let isOther: Bool
    }
    struct TrendBar: Equatable, Identifiable {
        let id: Int
        let label: String
        let valueText: String
        let heightFraction: Double
        let isCurrent: Bool
    }
    struct DashboardDisplay: Equatable {
        let periodLabel: String
        let scopeText: String
        let totalText: String
        let budgetText: String?
        let remainText: String?
        let consumedPercentText: String?
        let consumedFraction: Double?
        let pace: PaceBadge?
        let dayBudget: DayBudgetInfo?
        let donut: [DonutLegendItem]
        let trend: [TrendBar]
    }

    private let repository: LedgerRepository
    private let now: Date
    private let calendar: Calendar

    var kind: PeriodKind = .month
    var offset: Int = 0
    private(set) var display: DashboardDisplay?

    init(repository: LedgerRepository, now: Date, calendar: Calendar) {
        self.repository = repository
        self.now = now
        self.calendar = calendar
    }

    func load() {
        do {
            let summary = try repository.dashboardSummary(kind: kind, offset: offset, now: now, calendar: calendar)
            let categories = try repository.allCategories(includeArchived: true)
            display = build(summary, categories: categories)
        } catch {
            display = nil
        }
    }

    private func build(_ s: LedgerRepository.DashboardSummary, categories: [CategoryRef]) -> DashboardDisplay {
        let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        let pace: PaceBadge? = s.pace.flatMap { p in
            guard let ratio = p.deltaRatio else { return nil }
            let pct = Int((abs(ratio) * 100).doubleValue.rounded())
            let up = ratio > 0
            let note = kind == .year ? "작년 같은 시점보다" : "지난달 같은 시점보다"
            return PaceBadge(deltaText: "\(pct)%", direction: up ? .up : .down, note: note)
        }

        let dayBudget: DayBudgetInfo? = (kind == .day)
            ? s.budget.map { b in
                DayBudgetInfo(dayBudgetText: Won.string(b),
                              remainText: Won.string((b - s.totalExpense)))
              }
            : nil

        let legend: [DonutLegendItem] = s.donut.map { slice in
            let name = slice.isOther ? "기타" : (slice.categoryID.flatMap { byID[$0]?.name } ?? "기타")
            let color = slice.isOther ? "#A69B8C" : (slice.categoryID.flatMap { byID[$0]?.colorHex } ?? "#A69B8C")
            let pct = Int((slice.fraction * 100).rounded())
            return DonutLegendItem(
                id: slice.categoryID?.uuidString ?? "other",
                categoryID: slice.categoryID,
                name: name,
                colorHex: color,
                percentText: "\(pct)%",
                isOther: slice.isOther
            )
        }

        let scope: String = {
            switch kind {
            case .day: return "오늘 지출"
            case .month: return "이번 달 총지출"
            case .year: return "올해 총지출"
            }
        }()

        return DashboardDisplay(
            periodLabel: PeriodLabel.text(kind: kind, period: s.period, now: now, calendar: calendar),
            scopeText: scope,
            totalText: Won.string(s.totalExpense),
            budgetText: s.budget.map { Won.string($0) },
            remainText: s.remaining.map { Won.string($0) },
            consumedPercentText: s.consumedFraction.map { "\(Int(($0 * 100).rounded()))%" },
            consumedFraction: s.consumedFraction,
            pace: pace,
            dayBudget: dayBudget,
            donut: legend,
            trend: []   // 추세 막대는 Task 6에서 대시보드 화면과 함께 채운다(엔진 월별 합계 조합)
        )
    }
}
```

> `trend`는 이 태스크에선 빈 배열로 둔다(표시 모델 스캐폴딩). 추세 막대 데이터 조립은 Task 6에서 대시보드 화면 작업과 함께 추가한다 — 그때 이 배열을 채우는 로직과 테스트를 넣는다.

- [ ] **Step 4: 통과 확인 + 커밋**

`DashboardViewModelTests` 2 tests + 전체 GREEN. 커밋:
```bash
git add WadeMoney/Screens/Dashboard/DashboardViewModel.swift WadeMoneyTests/DashboardViewModelTests.swift
git commit -m "feat(ui): add DashboardViewModel display assembly"
```

---

### Task 6: 탭 셸 + 대시보드 화면

앱 루트를 5슬롯 탭 셸로 바꾸고, 대시보드 화면을 디자인 시스템 컴포넌트로 렌더한다. (통계 탭은 v1.1 비활성, 내역·설정 탭은 계획 4까지 플레이스홀더.)

**Files:**
- Create: `WadeMoney/Screens/RootTabView.swift`
- Create: `WadeMoney/Screens/Dashboard/DashboardScreen.swift`
- Create: `WadeMoney/Screens/Dashboard/DashboardComponents.swift`
- Modify: `WadeMoney/RootView.swift` (RootTabView로 위임)
- Modify: `WadeMoney/Screens/Dashboard/DashboardViewModel.swift` (추세 막대 채우기)
- Test: `WadeMoneyTests/DashboardTrendTests.swift`

**Interfaces:**
- Consumes: Task 2~5 산출물, `LedgerRepository`(환경에서 주입), `@Environment(\.modelContext)`
- Produces: `RootTabView`(탭 바 + 중앙 FAB), `DashboardScreen`(뷰모델 렌더), 추세 막대 데이터(월=최근 6개월 등).

- [ ] **Step 1: 추세 막대 실패 테스트 작성**

`WadeMoneyTests/DashboardTrendTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct DashboardTrendTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        return utc.date(from: comps)!
    }
    func makeRepo() throws -> (LedgerRepository, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        return (LedgerRepository(context: container.mainContext), container)
    }

    @Test func monthTrendHasSixBarsCurrentLast() throws {
        let (repo, container) = try makeRepo()
        let food = try repo.allCategories(includeArchived: false).first { $0.name == "식비" }!.id
        try repo.addTransaction(amount: 50_000, type: .expense, categoryID: food, memo: nil, date: date(2026, 7, 3))
        let vm = DashboardViewModel(repository: repo, now: date(2026, 7, 15), calendar: utc)
        vm.kind = .month
        vm.load()
        let d = try #require(vm.display)
        #expect(d.trend.count == 6)
        #expect(d.trend.last?.isCurrent == true)
        #expect(d.trend.last?.label == "7월")
        _ = container
    }
}
```

- [ ] **Step 2: RED 확인**

Run: `xcodebuild test ...`
Expected: `monthTrendHasSixBarsCurrentLast` 실패(trend가 빈 배열).

- [ ] **Step 3: 뷰모델에 추세 막대 조립 추가**

`DashboardViewModel`의 `build(...)`에서 `trend: []`를 `trend: buildTrend(...)`로 바꾸고 메서드 추가:

```swift
    private func buildTrend(currentPeriodStart: Date) -> [TrendBar] {
        let calc = periodCalculator()
        let count: Int
        switch kind {
        case .day: count = 7
        case .month: count = 6
        case .year: count = 12
        }
        let txns = (try? repository.allTransactions()) ?? []
        var raw: [(label: String, value: Decimal, isCurrent: Bool)] = []
        for i in stride(from: count - 1, through: 0, by: -1) {
            let p = calc.period(kind, offset: offset - i, from: now)
            let total = Aggregator.totalExpense(txns, in: p)
            raw.append((label: barLabel(for: p), value: total, isCurrent: i == 0))
        }
        let maxV = raw.map(\.value).max() ?? 0
        return raw.enumerated().map { idx, r in
            let frac = maxV > 0 ? (r.value / maxV).doubleValue : 0
            return TrendBar(id: idx, label: r.label, valueText: Won.string(r.value),
                            heightFraction: frac, isCurrent: r.isCurrent)
        }
    }

    private func periodCalculator() -> PeriodCalculator {
        let monthStartDay = (try? repository.settingsMonthStartDay()) ?? 1
        return PeriodCalculator(calendar: calendar, monthStartDay: monthStartDay)
    }

    private func barLabel(for p: Period) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: p.start)
        switch kind {
        case .day: return "\(c.day ?? 0)"
        case .month: return "\(c.month ?? 0)월"
        case .year: return "\(c.year ?? 0)"
        }
    }
```

그리고 `build(...)` 호출부에서 `trend: buildTrend(currentPeriodStart: s.period.start)`로 교체. `LedgerRepository`에 헬퍼 추가(`WadeMoney/Stores/LedgerRepository.swift`):

```swift
    func settingsMonthStartDay() throws -> Int {
        try SettingsStore(context: context).settings().monthStartDay
    }
```

- [ ] **Step 4: 추세 테스트 통과 확인**

Run: `xcodebuild test ...`
Expected: `DashboardTrendTests` PASS(월=6개, 마지막이 현재).

- [ ] **Step 5: 대시보드 컴포넌트 뷰 작성**

`WadeMoney/Screens/Dashboard/DashboardComponents.swift` — 히어로 예산 카드, 페이스 배지, 카테고리 도넛, 추세 막대를 디자인 시스템 토큰으로 렌더. (전체 SwiftUI 코드; `@Environment(\.colorScheme)`로 라이트/다크 색 선택.)

```swift
import SwiftUI
import WadeMoneyCore

private func card<Content: View>(_ scheme: ColorScheme, @ViewBuilder _ content: () -> Content) -> some View {
    let sh = WadeShadow.card(scheme)
    return content()
        .padding(WadeSpacing.cardPadding)
        .background(WadeColors.card(scheme))
        .clipShape(RoundedRectangle(cornerRadius: WadeRadius.card, style: .continuous))
        .shadow(color: sh.color, radius: sh.radius, y: sh.y)
}

struct PeriodSegment: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var kind: PeriodKind
    private let items: [(PeriodKind, String)] = [(.day, "일"), (.month, "월"), (.year, "연")]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.0) { item in
                Button { kind = item.0 } label: {
                    Text(item.1)
                        .font(WadeFont.pretendard(14, weight: .bold))
                        .foregroundStyle(kind == item.0 ? WadeColors.primary(scheme) : WadeColors.ink2(scheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(kind == item.0 ? WadeColors.card(scheme) : .clear,
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(WadeColors.card2(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.segment, style: .continuous))
    }
}

struct HeroBudgetCard: View {
    @Environment(\.colorScheme) private var scheme
    let display: DashboardViewModel.DashboardDisplay

    var body: some View {
        card(scheme) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .trim(from: 0, to: min(1, display.consumedFraction ?? 0))
                            .stroke(WadeColors.primary(scheme), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .background(Circle().stroke(WadeColors.track(scheme), lineWidth: 12))
                            .frame(width: 92, height: 92)
                        VStack(spacing: 1) {
                            Text(display.consumedPercentText ?? "—")
                                .font(WadeFont.pretendard(23, weight: .heavy))
                                .foregroundStyle(WadeColors.primary(scheme))
                            Text("소진").font(WadeFont.pretendard(10.5, weight: .semibold))
                                .foregroundStyle(WadeColors.ink3(scheme))
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(display.scopeText).font(WadeFont.pretendard(12.5, weight: .semibold))
                            .foregroundStyle(WadeColors.ink3(scheme))
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("₩").font(WadeFont.pretendard(13, weight: .bold)).foregroundStyle(WadeColors.ink2(scheme))
                            Text(display.totalText).font(WadeFont.pretendard(30, weight: .heavy))
                                .foregroundStyle(WadeColors.ink(scheme))
                        }
                        if let pace = display.pace { PaceBadgeView(pace: pace) }
                        if let dayB = display.dayBudget {
                            Text("일예산 \(dayB.dayBudgetText)원 중 \(dayB.remainText)원 남음")
                                .font(WadeFont.pretendard(11)).foregroundStyle(WadeColors.ink3(scheme))
                        }
                    }
                    Spacer(minLength: 0)
                }
                if let remain = display.remainText, let budget = display.budgetText {
                    ProgressView(value: min(1, display.consumedFraction ?? 0))
                        .tint(WadeColors.primary(scheme))
                    HStack {
                        Text("예산 \(budget)원").font(WadeFont.pretendard(12)).foregroundStyle(WadeColors.ink3(scheme))
                        Spacer()
                        Text("\(remain)원 남음").font(WadeFont.pretendard(12, weight: .bold)).foregroundStyle(WadeColors.ink2(scheme))
                    }
                }
            }
        }
    }
}

struct PaceBadgeView: View {
    @Environment(\.colorScheme) private var scheme
    let pace: DashboardViewModel.PaceBadge
    var body: some View {
        let up = pace.direction == .up
        let fg = up ? WadeColors.bad(scheme) : WadeColors.good(scheme)
        let bg = up ? WadeColors.badsoft(scheme) : WadeColors.goodsoft(scheme)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 3) {
                Icon(up ? "arrow_drop_up" : "arrow_drop_down", size: 17)
                Text(pace.deltaText).font(WadeFont.pretendard(12.5, weight: .bold))
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(bg, in: Capsule())
            Text(pace.note).font(WadeFont.pretendard(11)).foregroundStyle(WadeColors.ink3(scheme))
        }
    }
}

struct DonutCard: View {
    @Environment(\.colorScheme) private var scheme
    let total: String
    let legend: [DashboardViewModel.DonutLegendItem]
    var body: some View {
        card(scheme) {
            VStack(alignment: .leading, spacing: 16) {
                Text("카테고리 비중").font(WadeFont.pretendard(15, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                HStack(spacing: 20) {
                    DonutRing(legend: legend, centerTotal: total)
                        .frame(width: 128, height: 128)
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(legend) { item in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3).fill(Color(hex: item.colorHex)).frame(width: 10, height: 10)
                                Text(item.name).font(WadeFont.pretendard(13, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
                                Spacer()
                                Text(item.percentText).font(WadeFont.pretendard(13, weight: .heavy)).foregroundStyle(WadeColors.ink2(scheme))
                            }
                        }
                    }
                }
            }
        }
    }
}

struct DonutRing: View {
    let legend: [DashboardViewModel.DonutLegendItem]
    let centerTotal: String
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ZStack {
            let fracs = legend.map { Double($0.percentText.dropLast()) ?? 0 }
            let total = max(fracs.reduce(0,+), 1)
            var start = 0.0
            ForEach(Array(legend.enumerated()), id: \.offset) { idx, item in
                let sweep = (Double(item.percentText.dropLast()) ?? 0) / total
                Circle()
                    .trim(from: start, to: start + sweep)
                    .stroke(Color(hex: item.colorHex), lineWidth: 22)
                    .rotationEffect(.degrees(-90))
                let _ = (start += sweep)
            }
            VStack(spacing: 1) {
                Text("총지출").font(WadeFont.pretendard(10.5, weight: .semibold)).foregroundStyle(WadeColors.ink3(scheme))
                Text(centerTotal).font(WadeFont.pretendard(16, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
            }
        }
    }
}

struct TrendCard: View {
    @Environment(\.colorScheme) private var scheme
    let bars: [DashboardViewModel.TrendBar]
    var body: some View {
        card(scheme) {
            VStack(alignment: .leading, spacing: 18) {
                Text("지출 추세").font(WadeFont.pretendard(15, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(bars) { bar in
                        VStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(bar.isCurrent ? WadeColors.primary(scheme) : WadeColors.barmuted(scheme))
                                .frame(maxWidth: 20)
                                .frame(height: max(6, bar.heightFraction * 100))
                            Text(bar.label).font(WadeFont.pretendard(9.5, weight: bar.isCurrent ? .heavy : .semibold))
                                .foregroundStyle(bar.isCurrent ? WadeColors.ink(scheme) : WadeColors.ink3(scheme))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 112, alignment: .bottom)
            }
        }
    }
}
```

- [ ] **Step 6: 대시보드 화면 + 탭 셸 작성**

`WadeMoney/Screens/Dashboard/DashboardScreen.swift`:

```swift
import SwiftUI
import SwiftData
import WadeMoneyCore

struct DashboardScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        ScrollView {
            VStack(spacing: WadeSpacing.cardGap) {
                Text("한눈에").font(WadeFont.pretendard(30, weight: .heavy))
                    .foregroundStyle(WadeColors.ink(scheme))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let vm = viewModel, let d = vm.display {
                    PeriodSegment(kind: Binding(get: { vm.kind }, set: { vm.kind = $0; vm.load() }))
                    HStack(spacing: 14) {
                        Button { vm.offset -= 1; vm.load() } label: { Icon("chevron_left", size: 19) }
                        Text(d.periodLabel).font(WadeFont.pretendard(15, weight: .bold))
                        Button { vm.offset += 1; vm.load() } label: { Icon("chevron_right", size: 19) }
                    }
                    .foregroundStyle(WadeColors.ink2(scheme))
                    HeroBudgetCard(display: d)
                    DonutCard(total: d.totalText, legend: d.donut)
                    TrendCard(bars: d.trend)
                }
            }
            .padding(.horizontal, WadeSpacing.screenH)
            .padding(.top, WadeSpacing.contentTop)
            .padding(.bottom, WadeSpacing.contentBottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WadeColors.bg(scheme))
        .onAppear {
            if viewModel == nil {
                let vm = DashboardViewModel(
                    repository: LedgerRepository(context: modelContext),
                    now: Date(), calendar: .current)
                vm.load()
                viewModel = vm
            }
        }
    }
}
```

`WadeMoney/Screens/RootTabView.swift`:

```swift
import SwiftUI

struct RootTabView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var selection = 0
    @State private var showAdd = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selection {
                case 0: DashboardScreen()
                case 1: PlaceholderScreen(title: "내역")
                case 4: PlaceholderScreen(title: "설정")
                default: DashboardScreen()
                }
            }
            tabBar
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showAdd) { QuickAddSheet(onSaved: {}) }
    }

    private var tabBar: some View {
        HStack {
            tabButton(0, "space_dashboard", "한눈에")
            tabButton(1, "receipt_long", "내역")
            fab
            statsTab
            tabButton(4, "settings", "설정")
        }
        .padding(.horizontal, 26).padding(.top, 10).padding(.bottom, 26)
        .background(.ultraThinMaterial)
    }

    private func tabButton(_ idx: Int, _ icon: String, _ label: String) -> some View {
        let active = selection == idx
        return Button { selection = idx } label: {
            VStack(spacing: 3) {
                Icon(icon, size: 26)
                Text(label).font(WadeFont.pretendard(10, weight: .bold))
            }
            .foregroundStyle(active ? WadeColors.primary(scheme) : WadeColors.ink3(scheme))
            .frame(maxWidth: .infinity)
        }.buttonStyle(.plain)
    }

    private var statsTab: some View {
        Button { } label: {
            VStack(spacing: 3) {
                Icon("insights", size: 26); Text("통계").font(WadeFont.pretendard(10, weight: .bold))
            }
            .foregroundStyle(WadeColors.ink3(scheme)).opacity(0.5).frame(maxWidth: .infinity)
        }.buttonStyle(.plain).disabled(true)
    }

    private var fab: some View {
        Button { showAdd = true } label: {
            Icon("add", size: 30).foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(WadeColors.primary(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.fab, style: .continuous))
                .shadow(color: WadeColors.primary(scheme).opacity(0.4), radius: 20, y: 8)
        }.buttonStyle(.plain).offset(y: -14).frame(width: 60)
    }
}

struct PlaceholderScreen: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    var body: some View {
        VStack { Text(title).font(WadeFont.pretendard(30, weight: .heavy)) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WadeColors.bg(scheme))
    }
}
```

`WadeMoney/RootView.swift`를 다음으로 교체:

```swift
import SwiftUI

struct RootView: View {
    var body: some View { RootTabView() }
}

#Preview { RootView() }
```

> `QuickAddSheet`는 Task 7에서 만든다. Task 6에서는 컴파일을 위해 최소 스텁이 필요하면 Task 7 파일을 먼저 빈 스텁으로 두되, Task 7에서 완성한다. (실행 순서상 Task 7 시트가 없으면 `sheet` 콘텐츠가 미정의 → Task 7 완료 전까지 `showAdd` 트리거 버튼을 비활성화하거나 스텁 뷰를 둔다.)

- [ ] **Step 7: 빌드 + 스크린샷 확인**

```bash
xcodegen generate
xcodebuild build -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null; sleep 3
# 앱 설치 경로는 DerivedData의 .app — xcodebuild -showBuildSettings로 확인하거나 위 build 로그의 산출물 경로 사용
xcrun simctl install booted "$(xcodebuild -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -showBuildSettings 2>/dev/null | awk -F' = ' '/ CODESIGNING_FOLDER_PATH/ {print $2; exit}')"
xcrun simctl launch booted com.kimhyeongi.WadeMoney
sleep 2
xcrun simctl io booted screenshot /tmp/wade-dashboard.png
```
`/tmp/wade-dashboard.png`를 확인: "한눈에" 대제목, 일/월/연 세그먼트, 히어로 예산 카드(링·총액·페이스), 도넛, 추세 막대, 하단 탭바(5슬롯 + 중앙 FAB)가 디자인 시스템 톤(크림 배경, 제이드 포인트)으로 보이는지. 데이터가 없으면(시드만) 총지출 0·빈 도넛 상태로 보임 — 정상.

- [ ] **Step 8: 전체 스위트 통과 + 커밋**

Run: `xcodebuild test ...` — 전체 GREEN(추세 테스트 포함).
```bash
git add WadeMoney/Screens WadeMoney/RootView.swift WadeMoney/Stores/LedgerRepository.swift WadeMoneyTests/DashboardTrendTests.swift
git commit -m "feat(ui): add tab shell and dashboard screen"
```

---

### Task 7: `QuickAddViewModel` + 빠른 입력 시트

금액 키패드·지출/수입 토글·카테고리 그리드·메모·저장을 갖춘 바텀시트. 저장하면 리포지토리에 기록되고 대시보드가 갱신된다.

**Files:**
- Create: `WadeMoney/Screens/QuickAdd/QuickAddViewModel.swift`
- Create: `WadeMoney/Screens/QuickAdd/QuickAddSheet.swift`
- Test: `WadeMoneyTests/QuickAddViewModelTests.swift`

**Interfaces:**
- Consumes: `LedgerRepository`, `WadeMoneyCore`, `Icon`, `WadeColors`, `Won`
- Produces:
  - `@Observable @MainActor final class QuickAddViewModel(repository:)` — `var amountDigits: String`, `var type: TransactionKind`, `var selectedCategoryID: UUID?`, `var memo: String`, `var categories: [CategoryRef]`; `func tapKey(_:)`, `func backspace()`, `var amountDecimal: Decimal`, `var canSave: Bool`, `func save(date: Date) throws`
  - `struct QuickAddSheet: View`(`onSaved: () -> Void`)
  - 검증: `canSave = amount>0 && (type == .income || selectedCategoryID != nil)`. 수입 선택 시 카테고리 해제.

- [ ] **Step 1: 실패하는 테스트 작성**

`WadeMoneyTests/QuickAddViewModelTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct QuickAddViewModelTests {
    func makeVM() throws -> (QuickAddViewModel, LedgerRepository, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        try CategorySeeder.seedIfNeeded(container.mainContext)
        let repo = LedgerRepository(context: container.mainContext)
        return (QuickAddViewModel(repository: repo), repo, container)
    }
    func date() -> Date { Date(timeIntervalSince1970: 1_000_000) }

    @Test func keypadBuildsAmount() throws {
        let (vm, _, container) = try makeVM()
        vm.tapKey("4"); vm.tapKey("8"); vm.tapKey("00")
        #expect(vm.amountDecimal == 4800)
        vm.backspace()
        #expect(vm.amountDecimal == 480)
        _ = container
    }

    @Test func expenseRequiresCategory() throws {
        let (vm, _, container) = try makeVM()
        vm.tapKey("5"); vm.tapKey("0"); vm.tapKey("00")
        #expect(vm.canSave == false)            // 카테고리 미선택
        vm.selectedCategoryID = vm.categories.first?.id
        #expect(vm.canSave == true)
        _ = container
    }

    @Test func incomeNeedsNoCategoryAndSaves() throws {
        let (vm, repo, container) = try makeVM()
        vm.type = .income
        vm.tapKey("4"); vm.tapKey("5"); vm.tapKey("000")
        #expect(vm.selectedCategoryID == nil)
        #expect(vm.canSave == true)
        try vm.save(date: date())
        let all = try repo.allTransactions()
        #expect(all.count == 1)
        #expect(all[0].type == .income)
        _ = container
    }
}
```

- [ ] **Step 2: RED 확인**

Run: `xcodebuild test ...`
Expected: 컴파일 실패 — `QuickAddViewModel` 없음.

- [ ] **Step 3: 뷰모델 구현**

`WadeMoney/Screens/QuickAdd/QuickAddViewModel.swift`:

```swift
import Foundation
import Observation
import WadeMoneyCore

@MainActor
@Observable
final class QuickAddViewModel {
    private let repository: LedgerRepository

    var amountDigits: String = ""
    var type: TransactionKind = .expense { didSet { if type == .income { selectedCategoryID = nil } } }
    var selectedCategoryID: UUID?
    var memo: String = ""
    private(set) var categories: [CategoryRef] = []

    init(repository: LedgerRepository) {
        self.repository = repository
        categories = (try? repository.allCategories(includeArchived: false)) ?? []
    }

    var amountDecimal: Decimal { Decimal(string: amountDigits) ?? 0 }

    var canSave: Bool {
        amountDecimal > 0 && (type == .income || selectedCategoryID != nil)
    }

    func tapKey(_ key: String) {
        if amountDigits.isEmpty && (key == "0" || key == "00" || key == "000") { return }
        guard amountDigits.count + key.count <= 10 else { return }
        amountDigits += key
    }

    func backspace() {
        guard !amountDigits.isEmpty else { return }
        amountDigits.removeLast()
    }

    func save(date: Date) throws {
        guard canSave else { return }
        try repository.addTransaction(
            amount: amountDecimal,
            type: type,
            categoryID: type == .income ? nil : selectedCategoryID,
            memo: memo.isEmpty ? nil : memo,
            date: date
        )
    }
}
```

- [ ] **Step 4: 뷰모델 테스트 통과 확인**

Run: `xcodebuild test ...`
Expected: `QuickAddViewModelTests` 3 tests PASS.

- [ ] **Step 5: 시트 뷰 작성**

`WadeMoney/Screens/QuickAdd/QuickAddSheet.swift` — 금액 디스플레이, 지출/수입 토글, 4열 카테고리 그리드, 메모 입력, 3열 키패드, 저장 버튼. (전체 SwiftUI. AI 다듬기 버튼은 계획 5 연동 전이라 이 계획에선 넣지 않는다.)

```swift
import SwiftUI
import SwiftData
import WadeMoneyCore

struct QuickAddSheet: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var vm: QuickAddViewModel?
    let onSaved: () -> Void

    private let keys = ["1","2","3","4","5","6","7","8","9","00","0","←"]

    var body: some View {
        Group {
            if let vm { content(vm) }
        }
        .onAppear {
            if vm == nil { vm = QuickAddViewModel(repository: LedgerRepository(context: modelContext)) }
        }
        .presentationDetents([.large])
        .background(WadeColors.sheet(scheme))
    }

    @ViewBuilder private func content(_ vm: QuickAddViewModel) -> some View {
        VStack(spacing: 14) {
            HStack {
                Text(vm.type == .income ? "새 수입" : "새 지출").font(WadeFont.pretendard(20, weight: .heavy))
                Spacer()
                typeToggle(vm)
            }
            .padding(.top, 16)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("₩").font(WadeFont.pretendard(26, weight: .bold))
                Text(vm.amountDigits.isEmpty ? "0" : Won.string(vm.amountDecimal))
                    .font(WadeFont.pretendard(52, weight: .heavy))
            }
            .foregroundStyle(vm.amountDecimal > 0
                ? (vm.type == .income ? WadeColors.good(scheme) : WadeColors.ink(scheme))
                : WadeColors.ink3(scheme))

            if vm.type == .expense { categoryGrid(vm) }

            TextField("메모 (선택)", text: Binding(get: { vm.memo }, set: { vm.memo = $0 }))
                .font(WadeFont.pretendard(14.5))
                .padding(13)
                .background(WadeColors.card2(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.segment))

            keypad(vm)

            Button {
                try? vm.save(date: Date())
                onSaved(); dismiss()
            } label: {
                HStack(spacing: 6) { Icon("check", size: 22); Text("저장하기").font(WadeFont.pretendard(17, weight: .heavy)) }
                    .foregroundStyle(vm.canSave ? .white : WadeColors.ink3(scheme))
                    .frame(maxWidth: .infinity).padding(17)
                    .background(vm.canSave ? WadeColors.primary(scheme) : WadeColors.track(scheme),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain).disabled(!vm.canSave)
        }
        .padding(.horizontal, 20).padding(.bottom, 30)
    }

    private func typeToggle(_ vm: QuickAddViewModel) -> some View {
        HStack(spacing: 3) {
            ForEach([TransactionKind.expense, .income], id: \.self) { t in
                Button { vm.type = t } label: {
                    Text(t == .expense ? "지출" : "수입")
                        .font(WadeFont.pretendard(12.5, weight: .bold))
                        .foregroundStyle(vm.type == t ? .white : WadeColors.ink2(scheme))
                        .padding(.horizontal, 15).padding(.vertical, 7)
                        .background(vm.type == t ? (t == .income ? WadeColors.good(scheme) : WadeColors.primary(scheme)) : .clear,
                                    in: Capsule())
                }.buttonStyle(.plain)
            }
        }
        .padding(3).background(WadeColors.card2(scheme), in: Capsule())
    }

    private func categoryGrid(_ vm: QuickAddViewModel) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(vm.categories) { cat in
                let sel = vm.selectedCategoryID == cat.id
                Button { vm.selectedCategoryID = cat.id } label: {
                    VStack(spacing: 6) {
                        Icon(cat.iconName, size: 21).foregroundStyle(Color(hex: cat.colorHex))
                            .frame(width: 38, height: 38)
                            .background(Color(hex: cat.colorHex).opacity(0.13), in: RoundedRectangle(cornerRadius: WadeRadius.iconTile))
                        Text(cat.name).font(WadeFont.pretendard(11.5, weight: .bold))
                            .foregroundStyle(sel ? WadeColors.primary(scheme) : WadeColors.ink2(scheme))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(sel ? WadeColors.primarysoft(scheme) : WadeColors.card2(scheme),
                                in: RoundedRectangle(cornerRadius: WadeRadius.control))
                    .overlay(RoundedRectangle(cornerRadius: WadeRadius.control)
                        .stroke(sel ? WadeColors.primary(scheme) : .clear, lineWidth: 2))
                }.buttonStyle(.plain)
            }
        }
    }

    private func keypad(_ vm: QuickAddViewModel) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 9) {
            ForEach(keys, id: \.self) { key in
                Button {
                    if key == "←" { vm.backspace() } else { vm.tapKey(key) }
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

`RootTabView`의 `.sheet`가 이미 `QuickAddSheet(onSaved:)`를 참조하므로, 저장 후 대시보드 갱신을 위해 `onSaved`에서 대시보드가 다시 `load()`하도록 한다. 최소 방식: `RootTabView`에 `@State private var refreshToken = 0`을 두고 `onSaved: { refreshToken += 1 }`, `DashboardScreen`에 `.id(refreshToken)`을 걸어 재생성. (또는 `DashboardScreen`이 `.onAppear`가 아니라 시트 dismiss 시 `load()`하도록.) 이 태스크에서 그 배선을 완성한다.

- [ ] **Step 6: 빌드 + 스크린샷(입력 → 대시보드 반영) 확인**

```bash
xcodegen generate
xcodebuild build -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null; sleep 2
xcrun simctl install booted "$(xcodebuild -project WadeMoney.xcodeproj -scheme WadeMoney -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -showBuildSettings 2>/dev/null | awk -F' = ' '/ CODESIGNING_FOLDER_PATH/ {print $2; exit}')"
xcrun simctl launch booted com.kimhyeongi.WadeMoney
sleep 2
xcrun simctl io booted screenshot /tmp/wade-quickadd.png
```
FAB를 눌러 시트가 뜨는지, 키패드·카테고리 그리드·저장 버튼이 디자인대로 보이는지 스크린샷으로 확인(수동 상호작용은 시뮬레이터 UI로). 저장 후 대시보드 총지출/도넛이 갱신되는지 확인.

- [ ] **Step 7: 전체 스위트 통과 + 커밋**

Run: `xcodebuild test ...` — 전체 GREEN.
```bash
git add WadeMoney/Screens/QuickAdd WadeMoney/Screens/RootTabView.swift WadeMoneyTests/QuickAddViewModelTests.swift
git commit -m "feat(ui): add quick-add sheet and wire to dashboard refresh"
```

---

## Self-Review (계획 작성자 확인 완료)

- **스펙 커버리지**: 디자인 토큰(디자인 시스템 §1~§3)→Task 2·3; 폰트(Material Symbols·Pretendard, §9 결정)→Task 1; 대시보드(§5.1 한눈에: 세그먼트·히어로·페이스·도넛·추세)→Task 5·6; 빠른 입력(§5.6: 키패드·토글·그리드·저장, "3탭")→Task 7. **내역·설정·카테고리 관리·AI 리포트 화면 + AI 인사이트 카드 실제 데이터 + 위젯은 이 계획 밖**(계획 4·5·6).
- **뷰모델 순수성**: `now`/`calendar` 주입(테스트는 UTC 고정), `Date()`/`Calendar.current`는 화면 진입점(`DashboardScreen.onAppear`, `QuickAddSheet.save`)에서만.
- **플레이스홀더 스캔**: 실행 순서 의존성 1건 명시 — `RootTabView`가 `QuickAddSheet`(Task 7)를 참조하므로, Task 6 실행 시 시트 미완성이면 임시 스텁 후 Task 7에서 완성(Task 6 Step 6 주석에 기재). 그 외 플레이스홀더 없음.
- **타입 일관성**: `DashboardViewModel.DashboardDisplay`/`PaceBadge`/`DonutLegendItem`/`TrendBar`가 Task 5에서 정의되고 Task 6 뷰가 소비. `QuickAddViewModel.canSave`/`save(date:)`가 Task 7 시트와 테스트에서 일치. `LedgerRepository.settingsMonthStartDay()`는 Task 6에서 추가·사용.
- **폰트 이름 리스크**: `FontFamily.pretendard`/`.materialSymbols`의 PostScript 이름은 Task 1이 실제로 확인해 Task 3에서 확정(예시값은 교체 대상). Task 3 테스트가 실제 로드로 검증.

## 수동 검증 단계 (자동 스위트 밖)

각 뷰 태스크(6·7)는 시뮬레이터 스크린샷으로 **디자인 시스템 톤·레이아웃**을 확인한다. 라이트/다크 둘 다 보려면 시뮬레이터 Appearance를 토글해 재촬영. 픽셀 정확도(폰트 채움 축 등)는 디자인 시스템 §9의 후속 폴리시 대상.

## 다음 계획으로의 인터페이스

- 계획 4(나머지 화면): `RootTabView`의 내역·설정 플레이스홀더를 실제 화면으로 교체. 리뷰 백로그(대시보드 읽기 경로 쓰기 부작용, 기간별 fetch, `updateTransaction`, `totalIncome` 노출)를 이때 반영.
- 계획 5(AI): 대시보드 AI 인사이트 카드와 빠른 입력 "AI 다듬기" 버튼에 Foundation Models 연동(자리·데이터 구조는 이 계획에서 준비된 상태).
