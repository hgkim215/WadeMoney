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
