import Foundation

/// 스플래시 애니메이션의 각 구간 길이(초). 순수 데이터라 UI 없이 테스트 가능하다.
struct SplashTimeline: Equatable {
    let entrance: TimeInterval
    let donutApproach: TimeInterval
    let biteImpact: TimeInterval
    let chew: TimeInterval
    let crumbStagger: TimeInterval
    let hold: TimeInterval
    let exit: TimeInterval

    var total: TimeInterval {
        entrance + donutApproach + biteImpact + chew + hold + exit
    }

    /// 기본 애니메이션: 등장 → 도넛 접근 → 베어물기 → 씹기(입 오물오물+눈 두 번 깜빡) → 정지
    /// → 퇴장, 총 1.86초. 브랜드 인지는 남기되 콜드 스타트 대기감은 짧게 유지한다.
    static let standard = SplashTimeline(
        entrance: 0.36,
        donutApproach: 0.42,
        biteImpact: 0.16,
        chew: 0.54,
        crumbStagger: 0.06,
        hold: 0.22,
        exit: 0.16
    )

    /// Reduce Motion용: 슬라이드·바운스·씹기 구간을 사실상 0초로 접어 순간적으로 최종 포즈만
    /// 보여주고, 정지 구간만 조금 더 길게(0.4초) 유지한다.
    static let reduced = SplashTimeline(
        entrance: 0.20,
        donutApproach: 0,
        biteImpact: 0,
        chew: 0,
        crumbStagger: 0,
        hold: 0.40,
        exit: 0.20
    )

    static func active(reduceMotion: Bool) -> SplashTimeline {
        reduceMotion ? .reduced : .standard
    }
}

/// 스플래시를 콜드 스타트에서만 보여줄지 결정한다. XCTest/XCUITest 호스트에서는 항상
/// 건너뛴다 — WadeMoneyApp.init()이 같은 환경변수로 테스트 호스트를 감지하는 것과 동일한 패턴.
enum SplashVisibility {
    static func shouldShowOnLaunch(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        environment["XCTestConfigurationFilePath"] == nil
    }
}
