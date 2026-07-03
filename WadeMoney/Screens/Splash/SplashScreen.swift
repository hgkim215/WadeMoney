import SwiftUI

/// 콜드 스타트 시 짧게 보여주는 스플래시. 마스코트가 도넛을 베어무는 모션을 재생한 뒤
/// onFinished()를 호출해 RootView가 메인 화면으로 전환하도록 한다.
///
/// Reduce Motion이 켜져 있으면 SplashTimeline.reduced의 구간별 길이가 0에 가까워
/// (donutApproach/biteImpact/crumbStagger = 0) 슬라이드·바운스가 사실상 즉시 끝나고
/// 최종 포즈만 짧게 보여준 뒤 넘어간다 — 별도 분기 없이 같은 코드 경로로 처리한다.
struct SplashScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mascotState: MascotAnimationState = .initial
    @State private var opacity: Double = 1
    let onFinished: () -> Void

    var body: some View {
        WadeColors.bg(scheme)
            .ignoresSafeArea()
            .overlay {
                MascotView(state: mascotState)
            }
            .opacity(opacity)
            .task { await runTimeline() }
    }

    private func runTimeline() async {
        let timeline = SplashTimeline.active(reduceMotion: reduceMotion)

        withAnimation(.easeOut(duration: max(timeline.entrance, 0.001))) {
            mascotState.faceScale = 1.0
        }
        try? await Task.sleep(for: .seconds(timeline.entrance))

        withAnimation(.easeOut(duration: max(timeline.donutApproach, 0.001))) {
            mascotState.donutOffset = .zero
            mascotState.donutRotationDegrees = -16
        }
        try? await Task.sleep(for: .seconds(timeline.donutApproach))

        withAnimation(.spring(response: max(timeline.biteImpact, 0.001), dampingFraction: 0.6)) {
            mascotState.biteMaskProgress = 1
            mascotState.faceScale = 1.04
            mascotState.mouthOpenProgress = 1
        }
        for index in mascotState.crumbProgress.indices {
            let delay = Double(index) * timeline.crumbStagger
            Task {
                try? await Task.sleep(for: .seconds(delay))
                withAnimation(.easeOut(duration: max(timeline.biteImpact * 0.6, 0.001))) {
                    mascotState.crumbProgress[index] = 1
                }
            }
        }
        try? await Task.sleep(for: .seconds(timeline.biteImpact))

        withAnimation(.easeInOut(duration: max(timeline.biteImpact * 0.75, 0.001))) {
            mascotState.faceScale = 1.0
            mascotState.mouthOpenProgress = 0
            mascotState.crumbProgress = [0, 0, 0]
        }
        try? await Task.sleep(for: .seconds(timeline.hold))

        withAnimation(.easeInOut(duration: max(timeline.exit, 0.001))) {
            opacity = 0
        }
        try? await Task.sleep(for: .seconds(timeline.exit))

        onFinished()
    }
}

#Preview {
    SplashScreen(onFinished: {})
}
