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

    @Test func filledAndOutlineIconsUseDifferentFonts() {
        let filled = Icon.symbolFont(size: 20, filled: true)
        let outline = Icon.symbolFont(size: 20, filled: false)
        // FILL 축이 실제로 적용되면 두 폰트 디스크립터가 달라진다
        #expect(filled.fontDescriptor != outline.fontDescriptor)
    }

    @Test func newRadiusAndOnPrimaryTokensExist() {
        #expect(WadeRadius.button == 18)
        #expect(WadeRadius.smallTile == 11)
        #expect(WadeColors.onPrimary(.light) == WadeColors.onPrimary(.dark))
    }
}
