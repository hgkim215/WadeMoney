import SwiftUI
import WadeMoneyCore

struct CategoryDetailScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CategoryDetailViewModel?

    let categoryID: UUID
    let categoryName: String
    let categoryIconName: String
    let categoryColorHex: String
    let period: Period
    let periodLabel: String
    let repository: LedgerRepository

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WadeSpacing.cardGap) {
                backRow
                if let vm = viewModel {
                    summaryCard(vm)
                    Text("최근 거래")
                        .font(WadeFont.pretendard(15, weight: .heavy))
                        .foregroundStyle(WadeColors.ink(scheme))
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
        .onAppear {
            if viewModel == nil {
                let vm = CategoryDetailViewModel(
                    repository: repository,
                    categoryID: categoryID,
                    categoryName: categoryName,
                    period: period,
                    calendar: .current
                )
                vm.load()
                viewModel = vm
            }
        }
    }

    private var backRow: some View {
        Button { dismiss() } label: {
            HStack(spacing: 3) { Icon("chevron_left", size: 18); Text("카테고리별 지출").font(WadeFont.pretendard(14, weight: .semibold)) }
                .foregroundStyle(WadeColors.ink2(scheme))
        }.buttonStyle(.plain)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let sh = WadeShadow.card(scheme)
        return content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(WadeSpacing.cardPadding)
            .background(WadeColors.card(scheme))
            .clipShape(RoundedRectangle(cornerRadius: WadeRadius.card, style: .continuous))
            .shadow(color: sh.color, radius: sh.radius, y: sh.y)
    }

    private func summaryCard(_ vm: CategoryDetailViewModel) -> some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Icon(categoryIconName, size: 22).foregroundStyle(Color(hex: categoryColorHex))
                        .frame(width: 42, height: 42)
                        .background(Color(hex: categoryColorHex).opacity(0.13), in: RoundedRectangle(cornerRadius: WadeRadius.iconTile))
                    Text(categoryName).font(WadeFont.pretendard(19, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                    Spacer()
                    Text("지출 비중 \(vm.percentText)")
                        .font(WadeFont.pretendard(12, weight: .bold))
                        .foregroundStyle(WadeColors.primary(scheme))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(WadeColors.primarysoft(scheme), in: Capsule())
                }
                HStack(alignment: .lastTextBaseline) {
                    Text(periodLabel).font(WadeFont.pretendard(16, weight: .bold)).foregroundStyle(WadeColors.ink2(scheme))
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("₩").font(WadeFont.pretendard(15, weight: .bold)).foregroundStyle(WadeColors.ink2(scheme))
                        // 금액은 절대 말줄임하지 않는다 — 폭이 모자라면 글자를 줄여 전 자리수를 보여준다.
                        Text(vm.totalText).font(WadeFont.pretendard(30, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .layoutPriority(1)
                }
            }
        }
    }

    private func listCard(_ vm: CategoryDetailViewModel) -> some View {
        VStack(spacing: 0) {
            ForEach(vm.rows) { row in
                rowView(row)
                if row.id != vm.rows.last?.id {
                    Divider().overlay(WadeColors.line(scheme)).padding(.leading, 16)
                }
            }
        }
        .background(WadeColors.card(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.listCard, style: .continuous))
        .shadow(color: WadeShadow.list(scheme).color, radius: WadeShadow.list(scheme).radius, y: WadeShadow.list(scheme).y)
    }

    private func rowView(_ row: CategoryDetailViewModel.Row) -> some View {
        HStack(spacing: 13) {
            Text(row.dateText)
                .font(WadeFont.pretendard(12, weight: .semibold))
                .foregroundStyle(WadeColors.ink3(scheme))
                .frame(width: 36, alignment: .leading)
            // 예산 제외 뱃지를 없애 메모가 쓸 가로 공간을 넉넉히 확보한다 —
            // 대신 행 전체를 예산 제외 색 테두리로 감싼다(아래 overlay). 상세는 편집 시트에서 확인.
            Text(row.memo).font(WadeFont.pretendard(14.5, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer()
            // 금액은 항상 한 줄로 온전히 보여준다.
            Text(row.amountText).font(WadeFont.pretendard(15, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                .lineLimit(1)
                .layoutPriority(1)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .frame(minHeight: 64)
        .overlay {
            if row.showsBudgetExcludedLabel {
                RoundedRectangle(cornerRadius: WadeRadius.smallTile, style: .continuous)
                    .stroke(Color(hex: "#D3A850").opacity(scheme == .dark ? 0.6 : 0.7), lineWidth: 1.5)
                    .padding(2)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 11) {
            Icon("receipt_long", size: 38, filled: false).foregroundStyle(WadeColors.ink3(scheme))
                .frame(width: 74, height: 74)
                .background(WadeColors.card2(scheme), in: Circle())
            Text("거래 내역이 없어요")
                .font(WadeFont.pretendard(16, weight: .heavy))
                .foregroundStyle(WadeColors.ink2(scheme))
        }
        .frame(maxWidth: .infinity).padding(.top, 64)
    }
}
