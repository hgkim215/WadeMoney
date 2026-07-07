import Foundation
import Testing
@testable import WadeMoney

struct SplashTests {
    @Test func standardTimelineTotalsAboutOnePointEightSixSeconds() {
        let t = SplashTimeline.standard
        #expect(abs(t.total - 1.86) < 0.001)
    }

    @Test func standardTimelineHasChewPhase() {
        #expect(SplashTimeline.standard.chew > 0)
    }

    @Test func reducedTimelineIsShorterThanStandard() {
        #expect(SplashTimeline.reduced.total < SplashTimeline.standard.total)
    }

    @Test func reducedTimelineSkipsDonutApproachBiteAndChew() {
        let t = SplashTimeline.reduced
        #expect(t.donutApproach == 0)
        #expect(t.biteImpact == 0)
        #expect(t.chew == 0)
        #expect(t.crumbStagger == 0)
    }

    @Test func activePicksStandardWhenReduceMotionOff() {
        #expect(SplashTimeline.active(reduceMotion: false) == SplashTimeline.standard)
    }

    @Test func activePicksReducedWhenReduceMotionOn() {
        #expect(SplashTimeline.active(reduceMotion: true) == SplashTimeline.reduced)
    }

    @Test func showsSplashWhenNotRunningUnderTestHost() {
        #expect(SplashVisibility.shouldShowOnLaunch(environment: [:]) == true)
    }

    @Test func skipsSplashWhenRunningUnderTestHost() {
        #expect(SplashVisibility.shouldShowOnLaunch(environment: ["XCTestConfigurationFilePath": "/path"]) == false)
    }
}
