import SwiftUI
import SwiftData
import WadeMoneyCore

struct DashboardScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        ScrollView {
            VStack(spacing: WadeSpacing.cardGap) {
                Text("한눈에").font(WadeFont.pretendard(30, weight: .heavy))
                    .foregroundStyle(WadeColors.ink(scheme))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let vm = viewModel, let d = vm.display {
                    PeriodSegment(kind: Binding(get: { vm.kind }, set: { vm.kind = $0; vm.load() }))
                    HStack(spacing: 14) {
                        Button { vm.offset -= 1; vm.load() } label: { Icon("chevron_left", size: 19) }
                        Text(d.periodLabel).font(WadeFont.pretendard(15, weight: .bold))
                        Button { vm.offset += 1; vm.load() } label: { Icon("chevron_right", size: 19) }
                    }
                    .foregroundStyle(WadeColors.ink2(scheme))
                    HeroBudgetCard(display: d)
                    DonutCard(total: d.totalText, legend: d.donut)
                    TrendCard(bars: d.trend)
                }
            }
            .padding(.horizontal, WadeSpacing.screenH)
            .padding(.top, WadeSpacing.contentTop)
            .padding(.bottom, WadeSpacing.contentBottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WadeColors.bg(scheme))
        .onAppear {
            if viewModel == nil {
                let vm = DashboardViewModel(
                    repository: LedgerRepository(context: modelContext),
                    now: Date(), calendar: .current)
                vm.load()
                viewModel = vm
            }
        }
    }
}
