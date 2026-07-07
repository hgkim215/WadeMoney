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
    @State private var screenOpacity: Double = 1
    @State private var mascotOpacity: Double = 0
    @State private var wordmarkOpacity: Double = 0
    @State private var wordmarkOffset: CGFloat = 22
    @State private var taglineOpacity: Double = 0
    @State private var taglineOffset: CGFloat = 16
    @State private var loaderOpacity: Double = 0
    let onFinished: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                splashBackground(size)
                softBrandGlow(size)

                MascotView(state: mascotState)
                    .scaleEffect(1.4)
                    .opacity(mascotOpacity)
                    .position(x: size.width / 2, y: size.height * 0.36)

                brandLockup
                    .position(x: size.width / 2, y: size.height * 0.61)

                SplashLoaderDots(color: WadeColors.primary(scheme))
                    .opacity(loaderOpacity)
                    .position(x: size.width / 2, y: max(0, size.height - 86))
            }
            .ignoresSafeArea()
        }
        .opacity(screenOpacity)
        .task { await runTimeline() }
    }

    private func splashBackground(_ size: CGSize) -> some View {
        RadialGradient(
            colors: scheme == .dark
                ? [Color(hex: "2A211B"), Color(hex: "161311"), Color(hex: "0E0C0B")]
                : [Color(hex: "FCF8F0"), Color(hex: "F4EBDC"), Color(hex: "EADFCC")],
            center: UnitPoint(x: 0.5, y: 0.34),
            startRadius: 0,
            endRadius: max(size.width, size.height) * 0.78
        )
    }

    private func softBrandGlow(_ size: CGSize) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        WadeColors.primary(scheme).opacity(scheme == .dark ? 0.20 : 0.16),
                        WadeColors.primary(scheme).opacity(scheme == .dark ? 0.08 : 0.05),
                        WadeColors.primary(scheme).opacity(0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: min(size.width, size.height) * 0.75
                )
            )
            .frame(width: min(size.width * 1.45, 560), height: min(size.width * 1.45, 560))
            .position(x: size.width / 2, y: size.height * 0.34)
            .allowsHitTesting(false)
    }

    private var brandLockup: some View {
        VStack(spacing: 12) {
            Text("WadeMoney")
                .font(WadeFont.pretendard(34, weight: .heavy))
                .foregroundStyle(WadeColors.ink(scheme))
                .opacity(wordmarkOpacity)
                .offset(y: wordmarkOffset)

            Text("가볍게 기록하는 하루 지출 · 온디바이스 가계부")
                .font(WadeFont.pretendard(13.5, weight: .medium))
                .foregroundStyle(WadeColors.ink3(scheme))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 28)
                .opacity(taglineOpacity)
                .offset(y: taglineOffset)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("WadeMoney, 가볍게 기록하는 하루 지출 온디바이스 가계부")
    }

    private func runTimeline() async {
        let timeline = SplashTimeline.active(reduceMotion: reduceMotion)

        // 등장: 마스코트 페이드인. 도넛은 제자리에서 회전만 최종각(-16°)으로 살짝 정착.
        withAnimation(.easeOut(duration: max(timeline.entrance, 0.001))) {
            mascotOpacity = 1
            mascotState.donutRotationDegrees = -16
        }
        try? await Task.sleep(for: .seconds(timeline.entrance))

        // donutApproach 구간을 웅크림(anticipation)과 달려들기(lunge)로 나눈다.
        let windup = timeline.donutApproach * 0.34
        let lunge = timeline.donutApproach - windup

        // 웅크림: 도넛 반대쪽으로 조금 더 물러나 세로로 눌러(스쿼시) 힘을 모으고 입을 벌린다.
        withAnimation(.easeInOut(duration: max(windup, 0.001))) {
            mascotState.pigOffset = CGSize(width: -24, height: 15)
            mascotState.pigLeanDegrees = 6
            mascotState.pigScale = CGSize(width: 1.06, height: 0.93)
            mascotState.mouthOpenProgress = 0.82
        }
        try? await Task.sleep(for: .seconds(windup))

        // 달려들기: 스프링으로 도넛까지 뻗으며(스트레치) 최종 위치(.zero)로 돌진.
        withAnimation(.spring(response: max(lunge, 0.001), dampingFraction: 0.55)) {
            mascotState.pigOffset = .zero
            mascotState.pigLeanDegrees = -4
            mascotState.pigScale = CGSize(width: 0.97, height: 1.05)
        }
        try? await Task.sleep(for: .seconds(lunge))

        // 베어물기: 벌린 입을 앙 다물며(mouthOpen→0) 자국이 파이고 몸이 눌리며 부스러기가 튄다.
        withAnimation(.spring(response: max(timeline.biteImpact, 0.001), dampingFraction: 0.5)) {
            mascotState.biteMaskProgress = 1
            mascotState.pigScale = CGSize(width: 1.07, height: 0.95)
            mascotState.pigLeanDegrees = 0
            mascotState.mouthOpenProgress = 0
        }
        for index in mascotState.crumbProgress.indices {
            let delay = Double(index) * timeline.crumbStagger
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                withAnimation(.spring(response: max(timeline.biteImpact * 1.1, 0.001), dampingFraction: 0.6)) {
                    mascotState.crumbProgress[index] = 1
                }
            }
        }
        try? await Task.sleep(for: .seconds(timeline.biteImpact))

        let textRevealDuration = reduceMotion ? 0.12 : 0.50
        withAnimation(.easeOut(duration: textRevealDuration)) {
            wordmarkOpacity = 1
            wordmarkOffset = 0
            loaderOpacity = 1
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(timeline.chew * 0.45))
            withAnimation(.easeOut(duration: textRevealDuration)) {
                taglineOpacity = 1
                taglineOffset = 0
            }
        }

        // 씹기: 입을 두 번만 작게 여닫아 과한 플랩 느낌을 줄인다.
        let chewCount = 2
        let openBeat = timeline.chew * 0.20
        let closeBeat = timeline.chew * 0.30

        // 깜빡임: 씹는 중간에 한 번 감았다 뜬다. 지속시간·간격을 chew에 비례시켜
        // Reduce Motion(chew=0)에서는 별도 분기 없이 사실상 즉시 처리된다.
        Task { @MainActor in
            let gaps = [timeline.chew * 0.36]
            for gap in gaps {
                try? await Task.sleep(for: .seconds(gap))
                withAnimation(.easeInOut(duration: max(timeline.chew * 0.18, 0.001))) {
                    mascotState.eyeOpenProgress = 0.05
                }
                try? await Task.sleep(for: .seconds(max(timeline.chew * 0.18, 0.001)))
                withAnimation(.easeInOut(duration: max(timeline.chew * 0.22, 0.001))) {
                    mascotState.eyeOpenProgress = 1
                }
            }
        }

        for _ in 0..<chewCount {
            withAnimation(.easeOut(duration: max(openBeat, 0.001))) {
                mascotState.mouthOpenProgress = 0.32
                mascotState.pigScale = CGSize(width: 1.006, height: 0.992)
            }
            try? await Task.sleep(for: .seconds(openBeat))
            withAnimation(.easeInOut(duration: max(closeBeat, 0.001))) {
                mascotState.mouthOpenProgress = 0
                mascotState.pigScale = CGSize(width: 1, height: 1)
            }
            try? await Task.sleep(for: .seconds(closeBeat))
        }
        // 씹기 종료 시점의 상태(mouthOpen=0, eyeOpen=1, pigScale=1)가 곧 아이콘 정지 포즈다.

        try? await Task.sleep(for: .seconds(timeline.hold))

        // 퇴장: 스플래시 전체를 크로스페이드로 걷어낸다.
        withAnimation(.easeInOut(duration: max(timeline.exit, 0.001))) {
            screenOpacity = 0
        }
        try? await Task.sleep(for: .seconds(timeline.exit))

        onFinished()
    }
}

private struct SplashLoaderDots: View {
    let color: Color
    @State private var animating = false

    var body: some View {
        HStack(spacing: 11) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: 9, height: 9)
                    .scaleEffect(animating ? 1 : 0.82)
                    .opacity(animating ? 1 : 0.22)
                    .animation(
                        .easeInOut(duration: 0.70)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.18),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

#Preview {
    SplashScreen(onFinished: {})
}
