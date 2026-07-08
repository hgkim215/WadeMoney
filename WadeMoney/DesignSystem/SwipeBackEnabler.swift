import SwiftUI

/// `.navigationBarBackButtonHidden(true)`를 쓰면 SwiftUI가 인터랙티브 스와이프-백 제스처까지
/// 함께 꺼버린다. NavigationStack에서는 UINavigationController.interactivePopGestureRecognizer를
/// 되살리는 고전적인 우회법이 안정적으로 먹히지 않아서(SwiftUI가 매 렌더마다 다시 끄는 것으로 보임),
/// 대신 화면 왼쪽 가장자리에서 시작해 오른쪽으로 끌리는 일반 팬 제스처를 직접 붙여 좌표 기준으로
/// 판정하고, 인식되면 전달받은 액션(보통 dismiss)을 실행한다.
/// (UIScreenEdgePanGestureRecognizer 전용 엣지 인식은 XCUITest 합성 터치와 궁합이 나빠 대신 사용하지 않는다.)
private struct SwipeBackGesture: UIViewControllerRepresentable {
    let onSwipeBack: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        let recognizer = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handle(_:)))
        recognizer.delegate = context.coordinator
        controller.view.addGestureRecognizer(recognizer)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.onSwipeBack = onSwipeBack
    }

    func makeCoordinator() -> Coordinator { Coordinator(onSwipeBack: onSwipeBack) }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onSwipeBack: () -> Void
        private var startX: CGFloat = 0

        init(onSwipeBack: @escaping () -> Void) { self.onSwipeBack = onSwipeBack }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool { true }

        @objc func handle(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let location = recognizer.location(in: view)
            let translation = recognizer.translation(in: view)

            switch recognizer.state {
            case .began:
                startX = location.x - translation.x
            case .ended:
                let horizontalDistance = translation.x
                let verticalDrift = abs(translation.y)
                if startX < 40, horizontalDistance > 80, verticalDrift < 60 {
                    onSwipeBack()
                }
            default:
                break
            }
        }
    }
}

extension View {
    /// `.navigationBarBackButtonHidden(true)`와 함께 붙여서 왼쪽 가장자리 스와이프로
    /// 뒤로가기를 되살린다. `action`은 보통 해당 화면의 커스텀 뒤로가기 버튼과 같은 `dismiss()`.
    ///
    /// `.background()`가 아니라 `.overlay()`로 붙인다 — 화면 콘텐츠(List 등)가 이미 불투명한
    /// 배경을 가진 경우가 많아 뒤에 놓으면 완전히 가려져 터치도 못 받는다. 왼쪽 가장자리의
    /// 얇은 폭에만 배치해 일반적인 스크롤/탭 상호작용은 그대로 두고 엣지 스와이프 시작만 가로챈다.
    /// 제스처가 한번 시작되면 손가락이 그 폭을 벗어나도 UIKit이 계속 추적한다.
    func enableSwipeBack(action: @escaping () -> Void) -> some View {
        overlay(alignment: .leading) {
            SwipeBackGesture(onSwipeBack: action)
                .frame(width: 24)
                .frame(maxHeight: .infinity)
        }
    }
}
