import SwiftUI

struct RootTabView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var selection = 0
    @State private var showAdd = false
    @State private var quickAddCategoryID: UUID?
    @State private var dashboardRefreshToken = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selection {
                case 0: DashboardScreen(refreshToken: dashboardRefreshToken)
                case 1: HistoryScreen(refreshToken: dashboardRefreshToken)
                case 4: SettingsScreen()
                default: DashboardScreen(refreshToken: dashboardRefreshToken)
                }
            }
            tabBar
        }
        .ignoresSafeArea(.keyboard)
        .onOpenURL { url in
            guard DeepLink.isQuickAdd(url) else { return }
            quickAddCategoryID = DeepLink.categoryID(from: url)
            showAdd = true
        }
        .sheet(isPresented: $showAdd, onDismiss: { quickAddCategoryID = nil }) {
            QuickAddSheet(onSaved: { dashboardRefreshToken += 1 }, preselectedCategoryID: quickAddCategoryID)
        }
    }

    private var tabBar: some View {
        HStack {
            tabButton(0, "space_dashboard", "한눈에")
            tabButton(1, "receipt_long", "내역")
            fab
            statsTab
            tabButton(4, "settings", "설정")
        }
        .padding(.horizontal, WadeSpacing.screenH).padding(.top, 6).padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func tabButton(_ idx: Int, _ icon: String, _ label: String) -> some View {
        let active = selection == idx
        return Button { selection = idx } label: {
            VStack(spacing: 2) {
                Icon(icon, size: 23)
                Text(label).font(WadeFont.pretendard(9.2, weight: .bold))
            }
            .foregroundStyle(active ? WadeColors.primary(scheme) : WadeColors.ink3(scheme))
            .frame(maxWidth: .infinity)
        }.buttonStyle(.plain)
    }

    private var statsTab: some View {
        Button { } label: {
            VStack(spacing: 2) {
                Icon("insights", size: 23); Text("통계").font(WadeFont.pretendard(9.2, weight: .bold))
            }
            .foregroundStyle(WadeColors.ink3(scheme)).opacity(0.5).frame(maxWidth: .infinity)
        }.buttonStyle(.plain).disabled(true)
    }

    private var fab: some View {
        Button { showAdd = true } label: {
            Icon("add", size: 27).foregroundStyle(WadeColors.onPrimary(scheme))
                .frame(width: 52, height: 52)
                .background(WadeColors.primary(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.fab, style: .continuous))
                .shadow(color: WadeColors.primaryglow(scheme), radius: 16, y: 6)
        }.buttonStyle(.plain).offset(y: -8).frame(width: 56)
    }
}
