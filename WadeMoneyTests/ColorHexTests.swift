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

    @Test func primaryGlowTokenExists() {
        #expect(WadeColors.primaryglow(.light) != WadeColors.primaryglow(.dark))
    }
}
