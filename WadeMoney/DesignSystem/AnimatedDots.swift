import SwiftUI

/// "가져오는 중" 같은 진행 문구 뒤에 붙어 점 개수가 0~3개를 순환하며
/// 실제로 진행되고 있음을 시각적으로 표현한다. 진행률 수치가 아니라 반복 애니메이션일 뿐이다.
struct AnimatedDots: View {
    @State private var count = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(String(repeating: ".", count: count))
            .frame(width: 18, alignment: .leading)
            .onReceive(timer) { _ in
                count = (count + 1) % 4
            }
    }
}
