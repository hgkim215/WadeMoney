import SwiftUI
import SwiftData
import WadeMoneyCore

struct SettingsScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?
    @State private var showBudget = false
    @State private var showCategories = false
    @State private var budgetValue: Decimal = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("설정").font(WadeFont.pretendard(30, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                    if let vm = viewModel {
                        section("예산") {
                            row(icon: "account_balance_wallet", tint: WadeColors.primary(scheme), label: "이번 달 예산",
                                trailing: "₩\(vm.budgetText)") { showBudget = true }
                            row(icon: "event", tint: WadeColors.ink2(scheme), label: "월 시작일", trailing: vm.monthStartDayText, action: nil)
                        }
                        section("카테고리 · AI") {
                            row(icon: "category", tint: WadeColors.ink2(scheme), label: "카테고리 관리",
                                trailing: vm.categoryCountText) { showCategories = true }
                            aiToggleRow(vm)
                        }
                        section("동기화 · 데이터") {
                            row(icon: "cloud_done", tint: WadeColors.good(scheme), label: "iCloud 동기화", trailing: nil, action: nil)
                            row(icon: "ios_share", tint: WadeColors.ink2(scheme), label: "CSV 내보내기", trailing: nil) { exportCSV() }
                        }
                        Text("WadeMoney v1.0 · 데이터는 이 기기에 있어요")
                            .font(WadeFont.pretendard(11.5)).foregroundStyle(WadeColors.ink3(scheme))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, WadeSpacing.screenH)
                .padding(.top, WadeSpacing.contentTop).padding(.bottom, WadeSpacing.contentBottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WadeColors.bg(scheme))
            .navigationDestination(isPresented: $showCategories) { CategoryManageScreen() }
        }
        .sheet(isPresented: $showBudget) {
            BudgetSheet(current: budgetValue) { amount in viewModel?.setBudget(amount); viewModel?.load(); reloadBudgetValue() }
        }
        .onAppear {
            if viewModel == nil {
                let ctx = modelContext
                let vm = SettingsViewModel(settingsStore: SettingsStore(context: ctx),
                                           categoryStore: CategoryStore(context: ctx),
                                           now: Date(), calendar: .current)
                vm.load(); viewModel = vm; reloadBudgetValue()
            }
        }
    }

    private func reloadBudgetValue() {
        let ctx = modelContext
        let cal = Calendar.current
        let ym = YearMonth(year: cal.component(.year, from: Date()), month: cal.component(.month, from: Date()))
        budgetValue = (try? SettingsStore(context: ctx).budgetBook().amount(for: ym)) ?? 0
    }

    private func exportCSV() {
        let ctx = modelContext
        let repo = LedgerRepository(context: ctx)
        let records = (try? repo.transactions(filter: .all)) ?? []
        let cats = (try? repo.allCategories(includeArchived: true)) ?? []
        let csv = CSVExporter.csv(records, categories: cats, calendar: .current)
        // 데모: 파일로 쓰고 공유 시트는 후속. 여기선 콘솔·임시파일까지만.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("wademoney.csv")
        try? csv.data(using: .utf8)?.write(to: url)
    }

    @ViewBuilder private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(WadeFont.pretendard(12.5, weight: .bold)).foregroundStyle(WadeColors.ink3(scheme)).padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(WadeColors.card(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.listCard, style: .continuous))
        }
    }

    private func row(icon: String, tint: Color, label: String, trailing: String?, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            HStack(spacing: 13) {
                Icon(icon, size: 20).foregroundStyle(tint).frame(width: 36, height: 36)
                    .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                Text(label).font(WadeFont.pretendard(15, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
                Spacer()
                if let trailing { Text(trailing).font(WadeFont.pretendard(15, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme)) }
                if action != nil { Icon("chevron_right", size: 20, filled: false).foregroundStyle(WadeColors.ink3(scheme)) }
            }
            .padding(.horizontal, 16).padding(.vertical, 15)
        }.buttonStyle(.plain).disabled(action == nil)
    }

    private func aiToggleRow(_ vm: SettingsViewModel) -> some View {
        HStack(spacing: 13) {
            Icon("auto_awesome", size: 20).foregroundStyle(WadeColors.primary(scheme)).frame(width: 36, height: 36)
                .background(WadeColors.aitint2(scheme), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text("AI 기능").font(WadeFont.pretendard(15, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
                Text("온디바이스 · Apple Intelligence").font(WadeFont.pretendard(11.5)).foregroundStyle(WadeColors.ink3(scheme))
            }
            Spacer()
            Toggle("", isOn: Binding(get: { vm.aiEnabled }, set: { _ in vm.toggleAI() })).labelsHidden().tint(WadeColors.primary(scheme))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}
