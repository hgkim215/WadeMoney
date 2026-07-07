import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct TrendCardSelectionTests {
    private func bar(_ id: Int, isCurrent: Bool) -> DashboardViewModel.TrendBar {
        DashboardViewModel.TrendBar(id: id, label: "\(id)월", valueText: "\(id * 1000)", heightFraction: 0.5, isCurrent: isCurrent)
    }

    @Test func nilSelectionPicksCurrentBar() {
        let bars = [bar(0, isCurrent: false), bar(1, isCurrent: true)]
        let result = TrendCard.selectedBar(in: bars, id: nil)
        #expect(result?.id == 1)
    }

    @Test func explicitSelectionPicksThatBar() {
        let bars = [bar(0, isCurrent: false), bar(1, isCurrent: true)]
        let result = TrendCard.selectedBar(in: bars, id: 0)
        #expect(result?.id == 0)
    }

    @Test func unknownSelectionFallsBackToCurrentBar() {
        let bars = [bar(0, isCurrent: false), bar(1, isCurrent: true)]
        let result = TrendCard.selectedBar(in: bars, id: 99)
        #expect(result?.id == 1)
    }

    @Test func emptyBarsReturnsNil() {
        let result = TrendCard.selectedBar(in: [], id: nil)
        #expect(result == nil)
    }
}
