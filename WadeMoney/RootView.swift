import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var settingsModels: [AppSettingsModel]
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = SplashVisibility.shouldShowOnLaunch()
    @State private var showOnboarding = false
    @State private var pendingUpdate: UpdateInfo?
    let hasExistingData: Bool

    private let updateChecker = UpdateChecker()

    /// 여러 기기의 CloudKit 병합으로 설정 행이 잠깐 중복될 수 있다 — SettingsStore와 동일하게
    /// id 최솟값 행을 결정적으로 채택한다(둘 다 같은 규칙이어야 기기 간 동일하게 보인다).
    private var appearance: AppAppearance {
        let winner = settingsModels.min { $0.id < $1.id }
        return AppAppearance(rawValue: winner?.appearanceRaw ?? 0) ?? .system
    }

    private var didCompleteOnboarding: Bool {
        settingsModels.min { $0.id < $1.id }?.didCompleteOnboarding ?? false
    }

    var body: some View {
        ZStack {
            RootTabView()

            if let pendingUpdate, !showSplash, !showOnboarding {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .transition(.opacity)

                UpdateAvailablePopup(
                    version: pendingUpdate.version,
                    onLater: { self.pendingUpdate = nil },
                    onUpdate: {
                        let url = pendingUpdate.storeURL
                        self.pendingUpdate = nil
                        openURL(url)
                    }
                )
                .padding(.horizontal, WadeSpacing.screenH)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
                .zIndex(1)
            }

            if showOnboarding {
                OnboardingView(onFinished: {
                    showOnboarding = false
                    Task { await checkForUpdateAfterSplash() }
                })
                .zIndex(2)
            }

            if showSplash {
                SplashScreen(onFinished: {
                    showSplash = false
                    if OnboardingGate.shouldShow(didCompleteOnboarding: didCompleteOnboarding, hasExistingData: hasExistingData) {
                        showOnboarding = true
                    } else {
                        Task { await checkForUpdateAfterSplash() }
                    }
                })
                .zIndex(3)
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .task {
            guard !showSplash, !showOnboarding else { return }
            await checkForUpdateAfterSplash()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, !showSplash, !showOnboarding else { return }
            Task { await checkForUpdateAfterSplash() }
        }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .debugShowUpdatePrompt)) { _ in
            showSplash = false
            showOnboarding = false
            pendingUpdate = DebugUpdatePrompt.updateInfo
        }
        #endif
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: pendingUpdate)
    }

    @MainActor
    private func checkForUpdateAfterSplash() async {
        guard pendingUpdate == nil else { return }
        pendingUpdate = await updateChecker.check()
    }
}

#Preview {
    RootView(hasExistingData: false)
}
