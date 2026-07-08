import Foundation

/// 온보딩 자동 표시 여부를 결정하는 순수 함수. 신규 설치(기존 거래 데이터 없음)이고
/// 아직 완료하지 않은 경우에만 자동으로 보여준다 — 이미 데이터가 있는 기존 사용자는
/// didCompleteOnboarding 필드가 새로 추가되어 기본값 false를 갖더라도 제외된다.
enum OnboardingGate {
    static func shouldShow(didCompleteOnboarding: Bool, hasExistingData: Bool) -> Bool {
        !didCompleteOnboarding && !hasExistingData
    }
}
