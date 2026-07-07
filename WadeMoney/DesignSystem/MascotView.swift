import SwiftUI

/// 마스코트(도넛 먹는 돼지)의 애니메이션 가능한 상태. 모든 좌표는 200×200 authoring
/// 캔버스 기준이며, 앱 아이콘(AppIcon.appiconset) 생성에 쓰인 것과 동일한 지오메트리를 공유한다.
struct MascotAnimationState: Equatable {
    /// 돼지 몸통 그룹의 비등방 스케일. (1,1)이 기본. 웅크릴 땐 세로<1·가로>1(스쿼시),
    /// 도넛으로 뻗을 땐 세로>1·가로<1(스트레치)로 무게감을 준다.
    var pigScale: CGSize = CGSize(width: 1, height: 1)
    /// 돼지 몸통 그룹의 평행이동(캔버스pt). .zero면 아이콘과 동일한 최종 위치.
    /// 시작 시 도넛 반대쪽(좌하)으로 물러나 있다가 .zero로 달려들며 베어문다.
    var pigOffset: CGSize = .zero
    /// 돼지 몸통 기울기(도). 0이 기본. 웅크릴 때 뒤로(+), 달려들 때 앞으로(-) 살짝 기운다.
    var pigLeanDegrees: Double = 0
    /// 도넛의 최종 위치(캔버스 (158,124))로부터의 오프셋. .zero면 최종 위치.
    var donutOffset: CGSize = .zero
    /// 도넛 회전각(도). 최종값은 -16.
    var donutRotationDegrees: Double = -16
    /// 0=베어물기 전(완전한 원), 1=최종 베어문 자국(반지름 17.5pt) 완성.
    var biteMaskProgress: CGFloat = 1
    /// 0=입 다뭄, 1=크게 벌림. 씹는 동안은 작은 폭으로만 움직이고, 베어물 준비 때 크게 벌린다.
    var mouthOpenProgress: CGFloat = 0
    /// 눈 뜬 정도. 1=완전히 뜸(아이콘 상태), 0에 가까우면 감음. 씹는 도중 한 번 깜빡인다.
    var eyeOpenProgress: CGFloat = 1
    /// 부스러기 3개 각각의 비행 진행도(0=베어문 지점에 잠복, 1=아이콘상 최종 안착 위치).
    var crumbProgress: [CGFloat] = [1, 1, 1]

    /// 스플래시 시작 시점: 도넛은 제자리(회전만 살짝 큼)에 있고, 돼지는 도넛 반대쪽으로
    /// 물러나 웅크린 채 아직 베어물지 않은 상태. 부스러기는 베어문 지점에 잠복(진행도 0).
    static let initial = MascotAnimationState(
        pigScale: CGSize(width: 1, height: 1),
        pigOffset: CGSize(width: -20, height: 12),
        pigLeanDegrees: 4,
        donutOffset: .zero,
        donutRotationDegrees: -22,
        biteMaskProgress: 0,
        mouthOpenProgress: 0,
        eyeOpenProgress: 1,
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
        .accessibilityHidden(true)
    }

    private var pig: some View {
        let mouthTop: CGFloat = 154
        let mouthHeight = 15 + state.mouthOpenProgress * 8
        let mouthCenterY = mouthTop + mouthHeight / 2
        let tongueY = mouthTop + mouthHeight - 1

        return ZStack {
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
                .fill(Color(hex: "8A4150"))
                .frame(width: 26, height: mouthHeight)
                .position(x: 93, y: mouthCenterY)
            Ellipse()
                .fill(Color(hex: "EE8FA0"))
                .frame(width: 16, height: 10)
                .scaleEffect(x: 1, y: 1 + state.mouthOpenProgress * 0.35, anchor: .top)
                .opacity(0.72 + Double(state.mouthOpenProgress) * 0.28)
                .position(x: 93, y: tongueY)
        }
        .scaleEffect(x: state.pigScale.width, y: state.pigScale.height, anchor: Self.pigPivot)
        .rotationEffect(.degrees(state.pigLeanDegrees), anchor: Self.pigPivot)
        .offset(state.pigOffset)
    }

    /// 스쿼시·기울임의 회전 중심. 돼지 몸통 아래쪽(턱/발 부근, 캔버스 ~(94,144))에 두어
    /// 웅크렸다 뻗을 때 머리가 도넛 쪽으로 호를 그리며 움직이도록 한다.
    private static let pigPivot = UnitPoint(x: 0.47, y: 0.72)

    private func eye(center: CGPoint, highlightCenter: CGPoint) -> some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [Color(hex: "5B3B44"), Color(hex: "3A252C")], center: UnitPoint(x: 0.38, y: 0.30), startRadius: 0, endRadius: 14))
                .frame(width: 17, height: 20)
                .scaleEffect(x: 1, y: state.eyeOpenProgress, anchor: .center)
                .position(x: center.x, y: center.y)
            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: 5.5, height: 5.5)
                .scaleEffect(state.eyeOpenProgress, anchor: .center)
                .opacity(Double(state.eyeOpenProgress))
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
            crumb(color: "3E9E7A", size: 8, finalRotation: 20, cornerRadius: 2, destination: CGPoint(x: 116, y: 136), progress: state.crumbProgress[0])
            crumb(color: "E0A93F", size: 6, finalRotation: -15, cornerRadius: 2, destination: CGPoint(x: 107, y: 147), progress: state.crumbProgress[1])
            crumb(color: "EC8FB6", size: 5, finalRotation: 0, cornerRadius: 2.5, destination: CGPoint(x: 123.5, y: 149.5), progress: state.crumbProgress[2])
        }
    }

    /// 부스러기가 베어문 지점(canvas ~(128,135))에서 튀어나와 아이콘상 최종 위치로 포물선을
    /// 그리며 안착한다. progress=1이면 위치·크기·회전이 모두 아이콘 정지 프레임과 정확히 일치.
    private func crumb(color: String, size: CGFloat, finalRotation: Double, cornerRadius: CGFloat, destination: CGPoint, progress: CGFloat) -> some View {
        let origin = CGPoint(x: 128, y: 135)
        let p = progress
        let eased = 1 - pow(1 - p, 2)             // easeOut: 초반에 빠르게 튀어나감
        let x = origin.x + (destination.x - origin.x) * eased
        let arc = -11 * sin(Double(p) * .pi)      // 비행 중간에 살짝 떠올랐다 내려앉는 포물선
        let y = origin.y + (destination.y - origin.y) * eased + CGFloat(arc)
        let spin = finalRotation - 160 * (1 - Double(p)) // 회전하며 날아가 최종 각도로 정착
        return RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(hex: color))
            .frame(width: size, height: size)
            .scaleEffect(min(1, p * 1.5))
            .rotationEffect(.degrees(spin))
            .opacity(min(1, p * 2.5))
            .position(x: x, y: y)
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
