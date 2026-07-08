import SwiftUI

/// 온보딩 마지막(4번째) 페이지: 알림 권한 요청. 실제 스케줄링 호출은 OnboardingView가
/// SettingsViewModel.setDailyReminderEnabled를 통해 수행하고, 이 뷰는 두 액션만 노출한다.
struct OnboardingReminderPage: View {
    @Environment(\.colorScheme) private var scheme
    let onEnable: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Icon("notifications", size: 44)
                .foregroundStyle(WadeColors.onPrimary(scheme))
                .frame(width: 96, height: 96)
                .background(WadeColors.primary(scheme), in: Circle())
            VStack(spacing: 10) {
                Text("매일 잊지 않게 알려드릴게요")
                    .font(WadeFont.pretendard(24, weight: .heavy))
                    .foregroundStyle(WadeColors.ink(scheme))
                    .multilineTextAlignment(.center)
                Text("밤 10시(설정에서 변경 가능)에 오늘 지출을 기록했는지 알려드려요")
                    .font(WadeFont.pretendard(15))
                    .foregroundStyle(WadeColors.ink2(scheme))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 12) {
                Button(action: onEnable) {
                    Text("알림 받기")
                        .font(WadeFont.pretendard(17, weight: .heavy))
                        .foregroundStyle(WadeColors.onPrimary(scheme))
                        .frame(maxWidth: .infinity).padding(17)
                        .background(WadeColors.primary(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.button, style: .continuous))
                }.buttonStyle(.plain)

                Button(action: onLater) {
                    Text("나중에 하기")
                        .font(WadeFont.pretendard(15, weight: .semibold))
                        .foregroundStyle(WadeColors.ink2(scheme))
                        .frame(maxWidth: .infinity).padding(12)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, WadeSpacing.screenH)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
