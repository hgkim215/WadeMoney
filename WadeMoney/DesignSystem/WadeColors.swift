import SwiftUI
import UIKit

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
    static func primaryglow(_ s: ColorScheme) -> Color {
        s == .dark
            ? Color(red: 77/255, green: 180/255, blue: 140/255).opacity(0.35)
            : Color(red: 62/255, green: 158/255, blue: 122/255).opacity(0.40)
    }
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
    static func shadow(_ s: ColorScheme) -> Color {
        s == .dark
            ? Color.black.opacity(0.40)
            : Color(red: 120/255, green: 90/255, blue: 60/255).opacity(0.10)
    }
    /// primary/good 등 채워진 배경 위에 올라가는 텍스트·아이콘 색(라이트/다크 공통 흰색).
    static func onPrimary(_ s: ColorScheme) -> Color { .white }

    /// 예산 소진율에 따른 경고 색. 70%까지는 기본 primary(초록), 70~100%는 primary→bad(빨강)로
    /// 점진 보간, 100% 이상은 완전한 bad. "다가갈수록 점차 빨개지는" 효과를 위한 것.
    static func budgetPace(_ s: ColorScheme, fraction: Double) -> Color {
        let warnStart = 0.7
        guard fraction > warnStart else { return primary(s) }
        let t = min((fraction - warnStart) / (1 - warnStart), 1)
        return lerp(primary(s), bad(s), t)
    }

    private static func lerp(_ from: Color, _ to: Color, _ t: Double) -> Color {
        let a = UIColor(from).rgba
        let b = UIColor(to).rgba
        return Color(
            red: a.r + (b.r - a.r) * t,
            green: a.g + (b.g - a.g) * t,
            blue: a.b + (b.b - a.b) * t
        )
    }
}

private extension UIColor {
    var rgba: (r: Double, g: Double, b: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }
}
