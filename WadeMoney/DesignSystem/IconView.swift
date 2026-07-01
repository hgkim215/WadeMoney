import SwiftUI
import UIKit
import CoreText

/// Material Symbols Rounded 리거처 아이콘. filled=true면 FILL 축을 1로 적용(디자인의 채운 아이콘).
struct Icon: View {
    let name: String
    var size: CGFloat = 20
    var filled: Bool = true

    var body: some View {
        Text(name).font(Font(Icon.symbolFont(size: size, filled: filled)))
    }

    static func symbolFont(size: CGFloat, filled: Bool) -> UIFont {
        let base = UIFont(name: FontFamily.materialSymbols, size: size) ?? .systemFont(ofSize: size)
        // 'FILL' four-char axis identifier = 0x46494C4C
        let fillAxis = 0x46494C4C
        let variations: [Int: Int] = [fillAxis: filled ? 1 : 0]
        let descriptor = base.fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variations
        ])
        return UIFont(descriptor: descriptor, size: size)
    }
}
