import SwiftUI

enum FontFamily {
    /// Task 1의 FontRegistrationTests가 확인한 실제 PostScript 이름으로 설정.
    static let pretendard = "PretendardVariable-Regular"
    static let materialSymbols = "MaterialSymbolsRounded-Regular"
}

enum WadeFont {
    static func pretendard(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(FontFamily.pretendard, size: size).weight(weight)
    }
}
