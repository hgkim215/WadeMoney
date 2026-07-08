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

    // MARK: - stabilizedProjectedTotal (일회성 분리)

    @Test func stabilizedSeparatesOneOffFromRoutine() {
        // 일회성 300만(합의 30% 이상) + 일상 3만×3일 → 300만 + 3만×30 = 390만
        let p = Projection.stabilizedProjectedTotal(
            amounts: [3_000_000, 30_000, 30_000, 30_000], daysElapsed: 3, daysInPeriod: 30)
        #expect(p == 3_900_000)
    }

    @Test func stabilizedSingleExpenseProjectsItself() {
        // 지출 1건 = 합의 100% ≥ 30% → 일회성 → 예상치는 그 금액 그대로
        #expect(Projection.stabilizedProjectedTotal(amounts: [500_000], daysElapsed: 2, daysInPeriod: 30) == 500_000)
    }

    @Test func stabilizedWithoutOneOffMatchesLinear() {
        // 각 25%(< 30%) → 전부 일상 → 기존 선형 외삽과 동일
        let p = Projection.stabilizedProjectedTotal(
            amounts: [100_000, 100_000, 100_000, 100_000], daysElapsed: 10, daysInPeriod: 30)
        #expect(p == 1_200_000)
    }

    @Test func stabilizedThresholdBoundaryCountsAsOneOff() {
        // 30,000은 합 100,000의 정확히 30% → 경계 포함 → 일회성
        let p = Projection.stabilizedProjectedTotal(
            amounts: [30_000, 14_000, 14_000, 14_000, 14_000, 14_000], daysElapsed: 10, daysInPeriod: 30)
        #expect(p == 240_000)
    }

    @Test func stabilizedZeroElapsedReturnsZero() {
        #expect(Projection.stabilizedProjectedTotal(amounts: [10_000], daysElapsed: 0, daysInPeriod: 30) == 0)
    }
}
