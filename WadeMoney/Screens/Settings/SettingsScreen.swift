import MessageUI
import SwiftUI
import SwiftData
import UIKit
import WadeMoneyCore

struct SettingsScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Environment(CloudSyncMonitor.self) private var syncMonitor
    @State private var viewModel: SettingsViewModel?
    @State private var showCategories = false
    @State private var presentedSheet: SettingsSheet?
    @State private var settingsToast: String?
    @State private var settingsToastTask: Task<Void, Never>?

    private enum SettingsSheet: Identifiable {
        case budget
        case monthStartDay
        case notificationTime
        case share(URL)
        case feedbackMail

        var id: String {
            switch self {
            case .budget: return "budget"
            case .monthStartDay: return "monthStartDay"
            case .notificationTime: return "notificationTime"
            case .share(let url): return "share-\(url.absoluteString)"
            case .feedbackMail: return "feedbackMail"
            }
        }
    }

    /// 빌드 설정(MARKETING_VERSION)에서 주입되는 실제 앱 버전 — 하드코딩 금지.
    static let appVersion =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("설정").font(WadeFont.pretendard(30, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                        if let vm = viewModel {
                            section("예산") {
                                row(icon: "account_balance_wallet", tint: WadeColors.primary(scheme), label: "이번 달 예산",
                                    trailing: vm.budgetRowText) { presentedSheet = .budget }
                                row(icon: "event", tint: WadeColors.ink2(scheme), label: "월 시작일", trailing: vm.monthStartDayText) {
                                    presentedSheet = .monthStartDay
                                }
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
                                syncStatusRow()
                                backupCheckRow()
                                row(icon: "ios_share", tint: WadeColors.ink2(scheme), label: "CSV 내보내기", trailing: nil) { exportCSV() }
                            }
                            section("알림") {
                                dailyReminderToggleRow(vm)
                                if vm.dailyReminderEnabled {
                                    dailyReminderTimeRow(vm)
                                }
                            }
                            section("도움말") {
                                row(
                                    icon: "mail",
                                    tint: WadeColors.primary(scheme),
                                    label: "앱 개선 의견 보내기",
                                    subtitle: "메일로 의견을 보낼 수 있어요",
                                    trailing: nil
                                ) {
                                    startFeedbackMail()
                                }
                                #if DEBUG
                                row(
                                    icon: "new_releases",
                                    tint: WadeColors.bad(scheme),
                                    label: "업데이트 알림 미리보기",
                                    subtitle: "DEBUG 빌드에서만 표시돼요",
                                    trailing: nil
                                ) {
                                    DebugUpdatePrompt.requestPreview()
                                }
                                #endif
                            }
                            section("정보") {
                                legalRow(icon: "description", label: "이용약관", url: WadeMoneyLegal.termsOfService)
                                legalRow(icon: "privacy_tip", label: "개인정보처리방침", url: WadeMoneyLegal.privacyPolicy)
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

                if let settingsToast {
                    WadeToast(message: settingsToast)
                        .padding(.horizontal, WadeSpacing.screenH)
                        .padding(.bottom, 76)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 10)),
                            removal: .opacity.combined(with: .offset(y: 6))
                        ))
                        .allowsHitTesting(false)
                }
            }
            .background(WadeColors.bg(scheme))
            .navigationDestination(isPresented: $showCategories) { CategoryManageScreen() }
        }
        .sheet(item: $presentedSheet) { sheet in
            sheetContent(sheet)
        }
        .onAppear {
            if viewModel == nil {
                let ctx = modelContext
                let vm = SettingsViewModel(settingsStore: SettingsStore(context: ctx),
                                           categoryStore: CategoryStore(context: ctx),
                                           now: Date(), calendar: .current)
                vm.load(); viewModel = vm
                Task { await vm.reconcilePermission() }
            }
        }
        .onDisappear {
            settingsToastTask?.cancel()
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
            presentedSheet = .share(url)
        }
    }

    @ViewBuilder private func sheetContent(_ sheet: SettingsSheet) -> some View {
        switch sheet {
        case .budget:
            BudgetSheet(current: viewModel?.budget ?? 0) { amount in viewModel?.setBudget(amount) }
        case .monthStartDay:
            MonthStartDaySheet(current: viewModel?.monthStartDay ?? 1) { day in viewModel?.setMonthStartDay(day) }
        case .notificationTime:
            NotificationTimeSheet(
                hour: viewModel?.dailyReminderHour ?? 22,
                minute: viewModel?.dailyReminderMinute ?? 0
            ) { hour, minute in viewModel?.setDailyReminderTime(hour: hour, minute: minute) }
        case .share(let url):
            ActivityView(url: url)
        case .feedbackMail:
            MailComposeView(draft: makeFeedbackDraft()) {
                presentedSheet = nil
            }
            .ignoresSafeArea()
        }
    }

    private func startFeedbackMail() {
        guard MFMailComposeViewController.canSendMail() else {
            UIPasteboard.general.string = FeedbackMailDraft.supportEmail
            showSettingsToast("메일 앱이 없어 주소를 복사했어요")
            return
        }
        presentedSheet = .feedbackMail
    }

    private func makeFeedbackDraft() -> FeedbackMailDraft {
        FeedbackMailDraft.make(
            appVersion: Self.appVersion,
            buildNumber: Self.buildNumber,
            deviceModel: Self.deviceModel,
            systemVersion: UIDevice.current.systemVersion
        )
    }

    private func showSettingsToast(_ message: String) {
        settingsToastTask?.cancel()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            settingsToast = message
        }
        settingsToastTask = Task {
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    settingsToast = nil
                }
            }
        }
    }

    private static let buildNumber =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"

    private static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(String(UnicodeScalar(UInt8(value))))
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())

        if let action {
            Button(action: action) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }

    private func legalRow(icon: String, label: String, url: URL) -> some View {
        NavigationLink {
            LegalDocumentView(title: label, url: url)
        } label: {
            HStack(spacing: 13) {
                Icon(icon, size: 20).foregroundStyle(WadeColors.ink2(scheme)).frame(width: 36, height: 36)
                    .background(WadeColors.ink2(scheme).opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                Text(label).font(WadeFont.pretendard(15, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
                Spacer()
                Icon("chevron_right", size: 20, filled: false).foregroundStyle(WadeColors.ink3(scheme))
            }
            .padding(.horizontal, 16).padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func appearanceRow(_ vm: SettingsViewModel) -> some View {
        HStack(spacing: 13) {
            Icon("contrast", size: 20).foregroundStyle(WadeColors.ink2(scheme)).frame(width: 36, height: 36)
                .background(WadeColors.ink2(scheme).opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            Text("화면 모드").font(WadeFont.pretendard(15, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Spacer()
            Picker("화면 모드", selection: Binding(get: { vm.appearance }, set: { vm.setAppearance($0) })) {
                ForEach(AppAppearance.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 156)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func syncStatusRow() -> some View {
        switch syncMonitor.state {
        case .normal:
            return row(icon: "cloud_done", tint: WadeColors.good(scheme), label: "iCloud 동기화",
                       subtitle: "모든 기기에서 최신 상태로 유지돼요", subtitleColor: WadeColors.good(scheme), trailing: nil, action: nil)
        case .importing:
            return row(icon: "cloud_sync", tint: WadeColors.ink2(scheme), label: "iCloud 동기화",
                       subtitle: "iCloud에서 가져오는 중", subtitleColor: WadeColors.ink2(scheme), trailing: nil, action: nil)
        case .unavailable:
            return row(icon: "cloud_off", tint: WadeColors.ink3(scheme), label: "iCloud 동기화",
                       subtitle: "iCloud 로그인 상태를 확인해주세요 · 탭하여 새로고침", subtitleColor: WadeColors.ink3(scheme), trailing: nil) {
                recheckSyncStatus()
            }
        }
    }

    private func recheckSyncStatus() {
        syncMonitor.recheckSignIn()
        if syncMonitor.state == .unavailable {
            showSettingsToast("여전히 iCloud에 로그인되어 있지 않아요")
        }
    }

    private func backupCheckRow() -> some View {
        let unavailable = syncMonitor.state == .unavailable
        return row(
            icon: "cloud_upload",
            tint: unavailable ? WadeColors.ink3(scheme) : WadeColors.ink2(scheme),
            label: "iCloud 백업 상태 확인",
            trailing: unavailable ? "확인 불가" : nil,
            action: unavailable ? nil : { checkBackupStatus() }
        )
    }

    private func checkBackupStatus() {
        if syncMonitor.pendingExport {
            showSettingsToast("아직 업로드 중이에요. 네트워크 연결을 확인하고 잠시 후 다시 확인해주세요.")
        } else {
            showSettingsToast("모든 데이터가 iCloud에 안전하게 저장됐어요. 지금 앱을 삭제해도 괜찮아요.")
        }
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

    private func dailyReminderToggleRow(_ vm: SettingsViewModel) -> some View {
        HStack(spacing: 13) {
            Icon("notifications", size: 20).foregroundStyle(WadeColors.ink2(scheme)).frame(width: 36, height: 36)
                .background(WadeColors.ink2(scheme).opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            Text("오늘 지출 알림").font(WadeFont.pretendard(15, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
            Spacer()
            Toggle("", isOn: Binding(get: { vm.dailyReminderEnabled }, set: { newValue in
                Task {
                    let succeeded = await vm.setDailyReminderEnabled(newValue)
                    if newValue && !succeeded {
                        showSettingsToast("iOS 설정에서 알림 권한을 허용해주세요")
                    }
                }
            })).labelsHidden().tint(WadeColors.primary(scheme))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func dailyReminderTimeRow(_ vm: SettingsViewModel) -> some View {
        row(icon: "schedule", tint: WadeColors.ink2(scheme), label: "알림 시각", trailing: vm.dailyReminderTimeText) {
            presentedSheet = .notificationTime
        }
    }
}
