import Foundation
import Testing
@testable import WadeMoneyCore

struct ProjectionTests {
    @Test func scalesCumulativeToFullPeriod() {
        // 15일 동안 90만 → 30일 기준 180만
        #expect(Projection.projectedTotal(cumulative: 900_000, daysElapsed: 15, daysInPeriod: 30) == 1_800_000)
    }

    @Test func zeroElapsedReturnsZero() {
        #expect(Projection.projectedTotal(cumulative: 0, daysElapsed: 0, daysInPeriod: 30) == 0)
    }
}
