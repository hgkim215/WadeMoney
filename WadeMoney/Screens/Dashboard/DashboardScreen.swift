import SwiftUI
import SwiftData
import WadeMoneyCore

struct DashboardScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?
    @State private var showReport = false
    var refreshToken: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: WadeSpacing.cardGap) {
                    HStack {
                        Text("한눈에").font(WadeFont.pretendard(30, weight: .heavy))
                            .foregroundStyle(WadeColors.ink(scheme))
                        Spacer()
                        if let vm = viewModel, vm.showsAIReportEntry {
                            Button { showReport = true } label: {
                                HStack(spacing: 5) {
                                    Icon("auto_awesome", size: 15)
                                    Text("리포트").font(WadeFont.pretendard(12.5, weight: .bold))
                                }
                                .foregroundStyle(WadeColors.primary(scheme))
                                .padding(.horizontal, 13).padding(.vertical, 8)
                                .background(WadeColors.primarysoft(scheme), in: Capsule())
                            }.buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    if let vm = viewModel, let d = vm.display {
                        PeriodSegment(kind: Binding(get: { vm.kind }, set: { vm.kind = $0; reload(vm) }))
                        HStack(spacing: 14) {
                            Button { vm.offset -= 1; reload(vm) } label: { Icon("chevron_left", size: 19) }
                            Text(d.periodLabel).font(WadeFont.pretendard(15, weight: .bold))
                            Button { vm.offset += 1; reload(vm) } label: { Icon("chevron_right", size: 19) }
                        }
                        .foregroundStyle(WadeColors.ink2(scheme))
                        HeroBudgetCard(display: d)
                        if let insight = vm.insightText {
                            InsightCard(text: insight, isGood: vm.insightIsGood ?? true) { showReport = true }
                        }
                        DonutCard(total: d.totalText, hasExpense: d.hasExpense, legend: d.donut)
                        TrendCard(bars: d.trend)
                    }
                }
                .padding(.horizontal, WadeSpacing.screenH)
                .padding(.top, WadeSpacing.contentTop)
                .padding(.bottom, WadeSpacing.dashboardContentBottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WadeColors.bg(scheme))
            .navigationDestination(isPresented: $showReport) { AIReportScreen() }
            .onAppear {
                if viewModel == nil {
                    let vm = DashboardViewModel(
                        repository: LedgerRepository(context: modelContext),
                        now: Date(), calendar: .current)
                    reload(vm)
                    viewModel = vm
                }
            }
            .onChange(of: refreshToken) { if let vm = viewModel { reload(vm) } }
        }
    }

    private func reload(_ vm: DashboardViewModel) {
        vm.load()
        Task { await vm.refreshInsight() }
    }
}
