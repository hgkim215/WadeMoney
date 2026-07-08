import SwiftUI

/// 온보딩 1~3페이지가 공유하는 레이아웃: 아이콘(또는 마스코트) + 제목 + 설명.
/// icon이 nil이면 스플래시와 동일한 마스코트를 대신 보여준다(첫 페이지 전용).
struct OnboardingPage: View {
    @Environment(\.colorScheme) private var scheme
    let icon: String?
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            if let icon {
                Icon(icon, size: 44)
                    .foregroundStyle(WadeColors.onPrimary(scheme))
                    .frame(width: 96, height: 96)
                    .background(WadeColors.primary(scheme), in: Circle())
            } else {
                MascotView(state: .finalPose)
            }
            VStack(spacing: 10) {
                Text(title)
                    .font(WadeFont.pretendard(24, weight: .heavy))
                    .foregroundStyle(WadeColors.ink(scheme))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(WadeFont.pretendard(15))
                    .foregroundStyle(WadeColors.ink2(scheme))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
