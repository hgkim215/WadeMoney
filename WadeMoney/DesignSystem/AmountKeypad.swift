import SwiftUI

struct AmountKeypad: View {
    @Environment(\.colorScheme) private var scheme
    let onKey: (String) -> Void
    let onBackspace: () -> Void
    private let keys = ["1","2","3","4","5","6","7","8","9","00","0","←"]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 9) {
            ForEach(keys, id: \.self) { key in
                Button {
                    if key == "←" { onBackspace() } else { onKey(key) }
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
