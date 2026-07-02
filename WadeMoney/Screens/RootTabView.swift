import SwiftUI

struct RootTabView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var selection = 0
    @State private var showAdd = false
    @State private var dashboardRefreshToken = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selection {
                case 0: DashboardScreen(refreshToken: dashboardRefreshToken)
                case 1: HistoryScreen(refreshToken: dashboardRefreshToken)
                case 4: PlaceholderScreen(title: "설정")
                default: DashboardScreen(refreshToken: dashboardRefreshToken)
                }
            }
            tabBar
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showAdd) {
            QuickAddSheet(onSaved: { dashboardRefreshToken += 1 })
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
        .padding(.horizontal, 26).padding(.top, 10).padding(.bottom, 26)
        .background(.ultraThinMaterial)
    }

    private func tabButton(_ idx: Int, _ icon: String, _ label: String) -> some View {
        let active = selection == idx
        return Button { selection = idx } label: {
            VStack(spacing: 3) {
                Icon(icon, size: 26)
                Text(label).font(WadeFont.pretendard(10, weight: .bold))
            }
            .foregroundStyle(active ? WadeColors.primary(scheme) : WadeColors.ink3(scheme))
            .frame(maxWidth: .infinity)
        }.buttonStyle(.plain)
    }

    private var statsTab: some View {
        Button { } label: {
            VStack(spacing: 3) {
                Icon("insights", size: 26); Text("통계").font(WadeFont.pretendard(10, weight: .bold))
            }
            .foregroundStyle(WadeColors.ink3(scheme)).opacity(0.5).frame(maxWidth: .infinity)
        }.buttonStyle(.plain).disabled(true)
    }

    private var fab: some View {
        Button { showAdd = true } label: {
            Icon("add", size: 30).foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(WadeColors.primary(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.fab, style: .continuous))
                .shadow(color: WadeColors.primaryglow(scheme), radius: 20, y: 8)
        }.buttonStyle(.plain).offset(y: -14).frame(width: 60)
    }
}

struct PlaceholderScreen: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    var body: some View {
        VStack { Text(title).font(WadeFont.pretendard(30, weight: .heavy)) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WadeColors.bg(scheme))
    }
}
