import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var settingsModels: [AppSettingsModel]
    @State private var showSplash = SplashVisibility.shouldShowOnLaunch()

    /// 여러 기기의 CloudKit 병합으로 설정 행이 잠깐 중복될 수 있다 — SettingsStore와 동일하게
    /// id 최솟값 행을 결정적으로 채택한다(둘 다 같은 규칙이어야 기기 간 동일하게 보인다).
    private var appearance: AppAppearance {
        let winner = settingsModels.min { $0.id < $1.id }
        return AppAppearance(rawValue: winner?.appearanceRaw ?? 0) ?? .system
    }

    var body: some View {
        ZStack {
            RootTabView()
            if showSplash {
                SplashScreen(onFinished: { showSplash = false })
            }
        }
        .preferredColorScheme(appearance.colorScheme)
    }
}

#Preview {
    RootView()
}
