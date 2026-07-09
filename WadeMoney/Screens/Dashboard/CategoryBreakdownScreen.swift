import SwiftUI
import WadeMoneyCore

struct CategoryBreakdownScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CategoryBreakdownViewModel?
    @State private var selectedRow: CategoryBreakdownViewModel.Row?
    @State private var showDetail = false

    let period: Period
    let periodLabel: String
    let repository: LedgerRepository

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WadeSpacing.cardGap) {
                backRow
                Text("\(periodLabel) 카테고리별 지출")
                    .font(WadeFont.pretendard(22, weight: .heavy))
                    .foregroundStyle(WadeColors.ink(scheme))
                if let vm = viewModel {
                    if vm.rows.isEmpty {
                        emptyState
                    } else {
                        listCard(vm)
                    }
                }
            }
            .padding(.horizontal, WadeSpacing.screenH)
            .padding(.top, WadeSpacing.contentTop)
            .padding(.bottom, WadeSpacing.contentBottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WadeColors.bg(scheme))
        .navigationBarBackButtonHidden(true)
        .enableSwipeBack { dismiss() }
        .navigationDestination(isPresented: $showDetail) {
            if let row = selectedRow {
                CategoryDetailScreen(
                    categoryID: row.categoryID,
                    categoryName: row.name,
                    categoryIconName: row.iconName,
                    categoryColorHex: row.colorHex,
                    period: period,
                    periodLabel: periodLabel,
                    repository: repository
                )
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = CategoryBreakdownViewModel(repository: repository, period: period)
                vm.load()
                viewModel = vm
            }
        }
    }

    private var backRow: some View {
        Button { dismiss() } label: {
            HStack(spacing: 3) { Icon("chevron_left", size: 18); Text("대시보드").font(WadeFont.pretendard(14, weight: .semibold)) }
                .foregroundStyle(WadeColors.ink2(scheme))
        }.buttonStyle(.plain)
    }

    private func listCard(_ vm: CategoryBreakdownViewModel) -> some View {
        VStack(spacing: 0) {
            ForEach(vm.rows) { row in
                Button {
                    selectedRow = row
                    showDetail = true
                } label: { rowView(row) }
                .buttonStyle(.plain)
                if row.id != vm.rows.last?.id {
                    Divider().overlay(WadeColors.line(scheme)).padding(.leading, 16)
                }
            }
        }
        .background(WadeColors.card(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.listCard, style: .continuous))
        .shadow(color: WadeShadow.list(scheme).color, radius: WadeShadow.list(scheme).radius, y: WadeShadow.list(scheme).y)
    }

    private func rowView(_ row: CategoryBreakdownViewModel.Row) -> some View {
        HStack(spacing: 13) {
            Icon(row.iconName, size: 21).foregroundStyle(Color(hex: row.colorHex))
                .frame(width: 38, height: 38)
                .background(Color(hex: row.colorHex).opacity(0.13), in: RoundedRectangle(cornerRadius: WadeRadius.iconTile))
            // 카테고리 이름은 말줄임 대신 최대 2줄까지 감싸서 전체를 보여준다.
            Text(row.name).font(WadeFont.pretendard(14.5, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            // 금액은 항상 한 줄로 온전히 보여준다.
            VStack(alignment: .trailing, spacing: 2) {
                Text("₩\(row.amountText)").font(WadeFont.pretendard(14.5, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                    .lineLimit(1)
                Text(row.percentText).font(WadeFont.pretendard(11.5, weight: .bold)).foregroundStyle(WadeColors.ink3(scheme))
            }
            .layoutPriority(1)
            Icon("chevron_right", size: 16, filled: false).foregroundStyle(WadeColors.ink3(scheme))
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .frame(minHeight: 64)
    }

    private var emptyState: some View {
        VStack(spacing: 11) {
            Icon("category", size: 38, filled: false).foregroundStyle(WadeColors.ink3(scheme))
                .frame(width: 74, height: 74)
                .background(WadeColors.card2(scheme), in: Circle())
            Text("이 기간엔 지출이 없어요")
                .font(WadeFont.pretendard(16, weight: .heavy))
                .foregroundStyle(WadeColors.ink2(scheme))
        }
        .frame(maxWidth: .infinity).padding(.top, 64)
    }
}
