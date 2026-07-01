import Foundation
import CoreText
import UIKit
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
