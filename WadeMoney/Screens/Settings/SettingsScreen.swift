import SwiftUI
import SwiftData
import WadeMoneyCore

struct SettingsScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @State private var viewModel: SettingsViewModel?
    @State private var showBudget = false
    @State private var showMonthStartDay = false
    @State private var showCategories = false
    private struct ShareItem: Identifiable { let id = UUID(); let url: URL }
    @State private var shareItem: ShareItem?

    /// 빌드 설정(MARKETING_VERSION)에서 주입되는 실제 앱 버전 — 하드코딩 금지.
    static let appVersion =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("설정").font(WadeFont.pretendard(30, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                    if let vm = viewModel {
                        section("예산") {
                            row(icon: "account_balance_wallet", tint: WadeColors.primary(scheme), label: "이번 달 예산",
                                trailing: vm.budgetRowText) { showBudget = true }
                            row(icon: "event", tint: WadeColors.ink2(scheme), label: "월 시작일", trailing: vm.monthStartDayText) { showMonthStartDay = true }
                        }
                        section("카테고리 · AI") {
                            row(icon: "category", tint: WadeColors.ink2(scheme), label: "카테고리 관리",
                                trailing: vm.categoryCountText) { showCategories = true }
                            aiToggleRow(vm)
                        }
                        section("화면") {
                            appearanceRow(vm)
                        }
                        section("동기화 · 데이터") {
                            row(icon: "cloud_done", tint: WadeColors.good(scheme), label: "iCloud 동기화",
                                subtitle: "iCloud에 안전하게 보관돼요", subtitleColor: WadeColors.good(scheme), trailing: nil, action: nil)
                            row(icon: "ios_share", tint: WadeColors.ink2(scheme), label: "CSV 내보내기", trailing: nil) { exportCSV() }
                        }
                        section("정보") {
                            row(icon: "description", tint: WadeColors.ink2(scheme), label: "이용약관", trailing: nil) {
                                openURL(WadeMoneyLegal.termsOfService)
                            }
                            row(icon: "privacy_tip", tint: WadeColors.ink2(scheme), label: "개인정보처리방침", trailing: nil) {
                                openURL(WadeMoneyLegal.privacyPolicy)
                            }
                        }
                        Text("WadeMoney v\(Self.appVersion) · 데이터는 내 기기와 iCloud에만 보관돼요")
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
            BudgetSheet(current: viewModel?.budget ?? 0) { amount in viewModel?.setBudget(amount) }
        }
        .sheet(isPresented: $showMonthStartDay) {
            MonthStartDaySheet(current: viewModel?.monthStartDay ?? 1) { day in viewModel?.setMonthStartDay(day) }
        }
        .sheet(item: $shareItem) { item in ActivityView(url: item.url) }
        .onAppear {
            if viewModel == nil {
                let ctx = modelContext
                let vm = SettingsViewModel(settingsStore: SettingsStore(context: ctx),
                                           categoryStore: CategoryStore(context: ctx),
                                           now: Date(), calendar: .current)
                vm.load(); viewModel = vm
            }
        }
    }

    private func exportCSV() {
        let ctx = modelContext
        let repo = LedgerRepository(context: ctx)
        let records = (try? repo.transactions(filter: .all)) ?? []
        let cats = (try? repo.allCategories(includeArchived: true)) ?? []
        let csv = CSVExporter.csv(records, categories: cats, calendar: .current)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("wademoney.csv")
        if (try? csv.data(using: .utf8)?.write(to: url)) != nil {
            shareItem = ShareItem(url: url)
        }
    }

    @ViewBuilder private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(WadeFont.pretendard(12.5, weight: .bold)).foregroundStyle(WadeColors.ink3(scheme)).padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(WadeColors.card(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.listCard, style: .continuous))
                .shadow(color: WadeShadow.list(scheme).color, radius: WadeShadow.list(scheme).radius, y: WadeShadow.list(scheme).y)
        }
    }

    @ViewBuilder private func row(
        icon: String,
        tint: Color,
        label: String,
        subtitle: String? = nil,
        subtitleColor: Color? = nil,
        trailing: String?,
        action: (() -> Void)?
    ) -> some View {
        let content = HStack(spacing: 13) {
            Icon(icon, size: 20).foregroundStyle(tint).frame(width: 36, height: 36)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(WadeFont.pretendard(15, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
                if let subtitle {
                    Text(subtitle)
                        .font(WadeFont.pretendard(11.5, weight: .semibold))
                        .foregroundStyle(subtitleColor ?? WadeColors.ink3(scheme))
                }
            }
            Spacer()
            if let trailing { Text(trailing).font(WadeFont.pretendard(15, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme)) }
            if action != nil { Icon("chevron_right", size: 20, filled: false).foregroundStyle(WadeColors.ink3(scheme)) }
        }
        .padding(.horizontal, 16).padding(.vertical, 15)

        if let action {
            Button(action: action) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }

    private func appearanceRow(_ vm: SettingsViewModel) -> some View {
        HStack(spacing: 13) {
            Icon("contrast", size: 20).foregroundStyle(WadeColors.ink2(scheme)).frame(width: 36, height: 36)
                .background(WadeColors.ink2(scheme).opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            Text("화면 모드").font(WadeFont.pretendard(15, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
            Spacer()
            Picker("화면 모드", selection: Binding(get: { vm.appearance }, set: { vm.setAppearance($0) })) {
                ForEach(AppAppearance.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
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
