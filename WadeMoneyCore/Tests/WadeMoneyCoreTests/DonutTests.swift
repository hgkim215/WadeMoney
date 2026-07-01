import Foundation
import Testing
@testable import WadeMoneyCore

struct DonutTests {
    func totals(_ values: [Decimal]) -> [CategoryTotal] {
        values.map { CategoryTotal(categoryID: UUID(), total: $0) }
    }

    @Test func noOtherSliceWhenWithinMax() {
        let slices = Donut.slices(totals([500, 300, 200]), maxSlices: 6)
        #expect(slices.count == 3)
        #expect(slices.allSatisfy { !$0.isOther })
        #expect(slices[0].fraction == 0.5)   // 500/1000
    }

    @Test func mergesOverflowIntoOtherSlice() {
        // 8개 → maxSlices 6이면 상위 5개 + 기타(나머지 3개 합)
        let slices = Donut.slices(totals([100, 90, 80, 70, 60, 50, 40, 10]), maxSlices: 6)
        #expect(slices.count == 6)
        #expect(slices[5].isOther)
        #expect(slices[5].categoryID == nil)
        #expect(slices[5].total == 100)   // 50+40+10
    }

    @Test func ignoresZeroAndReturnsEmptyWhenNoSpend() {
        #expect(Donut.slices(totals([0, 0]), maxSlices: 6).isEmpty)
        #expect(Donut.slices([], maxSlices: 6).isEmpty)
    }
}
