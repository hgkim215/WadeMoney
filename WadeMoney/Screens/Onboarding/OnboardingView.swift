import SwiftUI

/// 앱 첫 실행 시(신규 설치 + 기존 데이터 없음) 자동으로 뜨는 4페이지 온보딩 투어.
/// 설정 화면의 "가이드 다시 보기"에서도 동일한 뷰를 시트로 재사용한다 — 완료 플래그를
/// 다시 true로 저장해도 멱등이라 재진입 경로를 따로 분기할 필요가 없다.
struct OnboardingView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @State private var selection = 0
    @State private var settingsViewModel: SettingsViewModel?
    let onFinished: () -> Void

    private let infoPages: [(icon: String?, title: String, message: String)] = [
        (nil, "WadeMoney에 오신 걸 환영해요", "가볍게 기록하는 하루 지출, 온디바이스 가계부예요"),
        ("add", "몇 번의 탭이면 끝나요", "가운데 + 버튼으로 금액·카테고리·메모만 입력하면 저장 끝"),
        ("auto_awesome", "AI가 지출을 정리해드려요", "카테고리 비중, 지출 추세를 온디바이스 AI가 자동으로 분석해요")
    ]

    private var reminderPageIndex: Int { infoPages.count }

    var body: some View {
        ZStack {
            WadeColors.bg(scheme).ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    TabView(selection: $selection) {
                        ForEach(Array(infoPages.enumerated()), id: \.offset) { index, page in
                            OnboardingPage(icon: page.icon, title: page.title, message: page.message)
                                .tag(index)
                        }
                        OnboardingReminderPage(onEnable: enableReminder, onLater: complete)
                            .tag(reminderPageIndex)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    if selection < reminderPageIndex {
                        Button("건너뛰기") { selection = reminderPageIndex }
                            .font(WadeFont.pretendard(14, weight: .semibold))
                            .foregroundStyle(WadeColors.ink3(scheme))
                            .padding(.horizontal, WadeSpacing.screenH)
                            .padding(.top, 18)
                    }
                }

                dotIndicator
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                if selection < reminderPageIndex {
                    Button {
                        selection += 1
                    } label: {
                        Text("다음")
                            .font(WadeFont.pretendard(17, weight: .heavy))
                            .foregroundStyle(WadeColors.onPrimary(scheme))
                            .frame(maxWidth: .infinity).padding(17)
                            .background(WadeColors.primary(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.button, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, WadeSpacing.screenH)
                    .padding(.bottom, 28)
                }
            }
        }
        .onAppear {
            if settingsViewModel == nil {
                let ctx = modelContext
                let vm = SettingsViewModel(settingsStore: SettingsStore(context: ctx),
                                           categoryStore: CategoryStore(context: ctx),
                                           now: Date(), calendar: .current)
                vm.load()
                settingsViewModel = vm
            }
        }
    }

    private var dotIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0...reminderPageIndex, id: \.self) { index in
                Circle()
                    .fill(index == selection ? WadeColors.primary(scheme) : WadeColors.line(scheme))
                    .frame(width: 7, height: 7)
            }
        }
    }

    private func enableReminder() {
        Task {
            await settingsViewModel?.setDailyReminderEnabled(true)
            complete()
        }
    }

    private func complete() {
        try? SettingsStore(context: modelContext).setDidCompleteOnboarding(true)
        onFinished()
    }
}

#Preview {
    OnboardingView(onFinished: {})
}
