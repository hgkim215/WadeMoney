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
