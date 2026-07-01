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
}
