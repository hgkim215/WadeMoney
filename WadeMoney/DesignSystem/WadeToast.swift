import SwiftUI

struct WadeToast: View {
    @Environment(\.colorScheme) private var scheme

    let message: String

    var body: some View {
        Text(message)
            .font(WadeFont.pretendard(13.5, weight: .bold))
            .foregroundStyle(WadeColors.toastfg(scheme))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(WadeColors.toastbg(scheme), in: Capsule())
            .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
    }
}
