import SwiftUI

/// 마스코트(도넛 먹는 돼지)의 애니메이션 가능한 상태. 모든 좌표는 200×200 authoring
/// 캔버스 기준이며, 앱 아이콘(AppIcon.appiconset) 생성에 쓰인 것과 동일한 지오메트리를 공유한다.
struct MascotAnimationState: Equatable {
    /// 돼지 얼굴 그룹 전체 스케일. 1.0이 기본, 베어무는 순간 잠깐 커진다.
    var faceScale: CGFloat = 1.0
    /// 도넛의 최종 위치(캔버스 (158,124))로부터의 오프셋. .zero면 최종 위치.
    var donutOffset: CGSize = .zero
    /// 도넛 회전각(도). 최종값은 -16.
    var donutRotationDegrees: Double = -16
    /// 0=베어물기 전(완전한 원), 1=최종 베어문 자국(반지름 17.5pt) 완성.
    var biteMaskProgress: CGFloat = 1
    /// 0=입 다뭄, 1=씹느라 살짝 벌어짐.
    var mouthOpenProgress: CGFloat = 0
    /// 부스러기 3개 각각의 등장 진행도(0=안 보임, 1=완전히 팝).
    var crumbProgress: [CGFloat] = [0, 0, 0]

    /// 스플래시 시작 시점: 도넛이 화면 위쪽 밖에 있고, 아직 베어물지 않은 완전한 원.
    static let initial = MascotAnimationState(
        faceScale: 0.85,
        donutOffset: CGSize(width: 0, height: -90),
        donutRotationDegrees: -34,
        biteMaskProgress: 0,
        mouthOpenProgress: 0,
        crumbProgress: [0, 0, 0]
    )

    /// 정지 포즈: 앱 아이콘과 픽셀 단위로 동일한 최종 상태(멤버 기본값 그대로).
    static let finalPose = MascotAnimationState()
}

/// 도넛 먹는 돼지 마스코트. 200×200pt 고정 캔버스. 배경은 그리지 않으므로(스플래시가
/// 자체 배경을 깔기 때문) 호출부에서 배경 위에 얹어 쓴다.
struct MascotView: View {
    var state: MascotAnimationState = .finalPose

    var body: some View {
        ZStack {
            pig
            donut
            crumbs
        }
        .frame(width: 200, height: 200)
    }

    private var pig: some View {
        ZStack {
            UnevenRoundedRectangle(topLeadingRadius: 24.84, bottomLeadingRadius: 3.68, bottomTrailingRadius: 23, topTrailingRadius: 24.84)
                .fill(Color(hex: "EA8FA4"))
                .frame(width: 46, height: 46)
                .rotationEffect(.degrees(-22))
                .position(x: 53, y: 59)

            UnevenRoundedRectangle(topLeadingRadius: 24.84, bottomLeadingRadius: 23, bottomTrailingRadius: 3.68, topTrailingRadius: 24.84)
                .fill(Color(hex: "EA8FA4"))
                .frame(width: 46, height: 46)
                .rotationEffect(.degrees(22))
                .position(x: 133, y: 59)

            UnevenRoundedRectangle(topLeadingRadius: 72, bottomLeadingRadius: 61.1, bottomTrailingRadius: 61.1, topTrailingRadius: 72)
                .fill(RadialGradient(colors: [Color(hex: "FAC3CE"), Color(hex: "EE97AB")], center: UnitPoint(x: 0.42, y: 0.30), startRadius: 0, endRadius: 90))
                .frame(width: 144, height: 130)
                .position(x: 93, y: 119)

            eye(center: CGPoint(x: 66.5, y: 100), highlightCenter: CGPoint(x: 64.25, y: 95.75))
            eye(center: CGPoint(x: 116.5, y: 100), highlightCenter: CGPoint(x: 114.25, y: 95.75))

            Ellipse().fill(Color(hex: "E8788C").opacity(0.42)).frame(width: 23, height: 13).position(x: 45.5, y: 124.5)
            Ellipse().fill(Color(hex: "E8788C").opacity(0.42)).frame(width: 23, height: 13).position(x: 140.5, y: 124.5)

            Ellipse()
                .fill(RadialGradient(colors: [Color(hex: "F2AAB8"), Color(hex: "E0899B")], center: UnitPoint(x: 0.42, y: 0.32), startRadius: 0, endRadius: 36))
                .frame(width: 58, height: 40).position(x: 93, y: 138)
            Ellipse().fill(Color(hex: "B0687A")).frame(width: 8, height: 13).position(x: 83.5, y: 138)
            Ellipse().fill(Color(hex: "B0687A")).frame(width: 8, height: 13).position(x: 98.5, y: 138)

            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 13, bottomTrailingRadius: 13, topTrailingRadius: 0)
                .fill(Color(hex: "8A4150")).frame(width: 26, height: 15).position(x: 93, y: 161.5)
            Ellipse()
                .fill(Color(hex: "EE8FA0"))
                .frame(width: 16, height: 10)
                .scaleEffect(x: 1, y: 1 + state.mouthOpenProgress * 0.3, anchor: .top)
                .position(x: 93, y: 168)
        }
        .scaleEffect(state.faceScale)
    }

    private func eye(center: CGPoint, highlightCenter: CGPoint) -> some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [Color(hex: "5B3B44"), Color(hex: "3A252C")], center: UnitPoint(x: 0.38, y: 0.30), startRadius: 0, endRadius: 14))
                .frame(width: 17, height: 20)
                .position(x: center.x, y: center.y)
            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: 5.5, height: 5.5)
                .position(x: highlightCenter.x, y: highlightCenter.y)
        }
    }

    private var donut: some View {
        donutRing
            .frame(width: 72, height: 72)
            .compositingGroup()
            .rotationEffect(.degrees(state.donutRotationDegrees))
            .shadow(color: Color(red: 90.0 / 255, green: 66.0 / 255, blue: 40.0 / 255).opacity(0.24), radius: 6, x: 0, y: 6)
            .position(x: 158 + state.donutOffset.width, y: 124 + state.donutOffset.height)
    }

    private var donutRing: some View {
        let stops: [Gradient.Stop] = [
            .init(color: Color(hex: "3E9E7A"), location: 0.0 / 360),
            .init(color: Color(hex: "3E9E7A"), location: 160.0 / 360),
            .init(color: Color(hex: "FBF6EC"), location: 160.0 / 360),
            .init(color: Color(hex: "FBF6EC"), location: 165.0 / 360),
            .init(color: Color(hex: "E0A93F"), location: 165.0 / 360),
            .init(color: Color(hex: "E0A93F"), location: 244.0 / 360),
            .init(color: Color(hex: "FBF6EC"), location: 244.0 / 360),
            .init(color: Color(hex: "FBF6EC"), location: 249.0 / 360),
            .init(color: Color(hex: "6F9FD8"), location: 249.0 / 360),
            .init(color: Color(hex: "6F9FD8"), location: 300.0 / 360),
            .init(color: Color(hex: "FBF6EC"), location: 300.0 / 360),
            .init(color: Color(hex: "FBF6EC"), location: 305.0 / 360),
            .init(color: Color(hex: "EC8FB6"), location: 305.0 / 360),
            .init(color: Color(hex: "EC8FB6"), location: 355.0 / 360),
            .init(color: Color(hex: "FBF6EC"), location: 355.0 / 360),
            .init(color: Color(hex: "FBF6EC"), location: 360.0 / 360),
        ]
        return ZStack {
            Circle()
                .fill(AngularGradient(gradient: Gradient(stops: stops), center: .center))
                .frame(width: 72, height: 72)
                .position(x: 36, y: 36)

            Circle()
                .fill(Color.black)
                .frame(width: 35 * state.biteMaskProgress, height: 35 * state.biteMaskProgress)
                .position(x: 4, y: 39)
                .blendMode(.destinationOut)

            Circle()
                .fill(LinearGradient(colors: [Color(hex: "FBF6EC"), Color(hex: "F1E6D5")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 30, height: 30)
                .position(x: 36, y: 36)

            Text("\u{20A9}")
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(Color(hex: "2E8E6E"))
                .position(x: 36, y: 36)
        }
    }

    private var crumbs: some View {
        ZStack {
            crumb(color: "3E9E7A", size: 8, rotation: 20, cornerRadius: 2, position: CGPoint(x: 116, y: 136), progress: state.crumbProgress[0])
            crumb(color: "E0A93F", size: 6, rotation: -15, cornerRadius: 2, position: CGPoint(x: 107, y: 147), progress: state.crumbProgress[1])
            crumb(color: "EC8FB6", size: 5, rotation: 0, cornerRadius: 2.5, position: CGPoint(x: 123.5, y: 149.5), progress: state.crumbProgress[2])
        }
    }

    private func crumb(color: String, size: CGFloat, rotation: Double, cornerRadius: CGFloat, position: CGPoint, progress: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(hex: color))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .opacity(progress)
            .position(x: position.x, y: position.y - 6 * progress)
    }
}

#Preview("최종 포즈") {
    MascotView(state: .finalPose)
        .padding(40)
        .background(Color(hex: "F6F0E6"))
}

#Preview("시작 포즈") {
    MascotView(state: .initial)
        .padding(40)
        .background(Color(hex: "F6F0E6"))
}
