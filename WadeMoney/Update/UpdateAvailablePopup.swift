import SwiftUI

struct UpdateAvailablePopup: View {
    @Environment(\.colorScheme) private var scheme

    let version: String
    let onLater: () -> Void
    let onUpdate: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Icon("new_releases", size: 34)
                .foregroundStyle(WadeColors.primary(scheme))
                .frame(width: 62, height: 62)
                .background(WadeColors.primarysoft(scheme), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(spacing: 7) {
                Text("새 버전이 있어요")
                    .font(WadeFont.pretendard(21, weight: .heavy))
                    .foregroundStyle(WadeColors.ink(scheme))

                Text("WadeMoney \(version) 업데이트가 준비됐어요.")
                    .font(WadeFont.pretendard(14, weight: .semibold))
                    .foregroundStyle(WadeColors.ink2(scheme))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button(action: onUpdate) {
                    Text("업데이트하기")
                        .font(WadeFont.pretendard(15, weight: .heavy))
                        .foregroundStyle(WadeColors.onPrimary(scheme))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(WadeColors.primary(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.button, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onLater) {
                    Text("나중에")
                        .font(WadeFont.pretendard(14, weight: .bold))
                        .foregroundStyle(WadeColors.ink3(scheme))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 18)
        .frame(maxWidth: 320)
        .background(WadeColors.card(scheme), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(scheme == .dark ? 0.34 : 0.16), radius: 28, y: 14)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    ZStack {
        WadeColors.bg(.light).ignoresSafeArea()
        UpdateAvailablePopup(version: "1.1.0", onLater: {}, onUpdate: {})
            .padding(24)
    }
}
