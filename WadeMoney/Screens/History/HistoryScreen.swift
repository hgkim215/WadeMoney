import SwiftUI
import SwiftData
import WadeMoneyCore

struct HistoryScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HistoryViewModel?
    @State private var repository: LedgerRepository?
    @State private var editingRecord: TransactionRecord?
    @State private var pendingDeleteID: UUID?
    let refreshToken: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("내역").font(WadeFont.pretendard(30, weight: .heavy))
                    .foregroundStyle(WadeColors.ink(scheme))
                    .padding(.bottom, 16)

                if let vm = viewModel {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(vm.chips) { chip in
                                Button {
                                    vm.filter = chip.filter; vm.load()
                                } label: {
                                    Text(chip.label).font(WadeFont.pretendard(13, weight: .bold))
                                        .foregroundStyle(chip.isSelected ? WadeColors.onPrimary(scheme) : WadeColors.ink2(scheme))
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(chip.isSelected ? WadeColors.primary(scheme) : WadeColors.card(scheme), in: Capsule())
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.bottom, 16)

                    if vm.isEmpty {
                        emptyState
                    } else {
                        ForEach(vm.groups) { group in
                            groupView(group)
                        }
                    }
                }
            }
            .padding(.horizontal, WadeSpacing.screenH)
            .padding(.top, WadeSpacing.contentTop)
            .padding(.bottom, WadeSpacing.contentBottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WadeColors.bg(scheme))
        .sheet(item: $editingRecord) { rec in
            QuickAddSheet(onSaved: { viewModel?.load() }, editing: rec)
        }
        .confirmationDialog(
            "이 내역을 삭제할까요?",
            isPresented: Binding(get: { pendingDeleteID != nil }, set: { if !$0 { pendingDeleteID = nil } }),
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                if let id = pendingDeleteID { try? repository?.deleteTransaction(id: id); viewModel?.load() }
                pendingDeleteID = nil
            }
            Button("취소", role: .cancel) { pendingDeleteID = nil }
        }
        .onChange(of: refreshToken) { viewModel?.load() }
        .onAppear {
            if viewModel == nil {
                let repo = LedgerRepository(context: modelContext)
                repository = repo
                let vm = HistoryViewModel(repository: repo, now: Date(), calendar: .current)
                vm.load(); viewModel = vm
            }
        }
    }

    private func groupView(_ group: HistoryViewModel.DayGroup) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(group.dateLabel).font(WadeFont.pretendard(13.5, weight: .heavy))
                if let tag = group.tag {
                    Text(tag).font(WadeFont.pretendard(10.5, weight: .bold))
                        .foregroundStyle(WadeColors.primary(scheme))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(WadeColors.primarysoft(scheme), in: Capsule())
                }
                Spacer()
                Text(group.sumText).font(WadeFont.pretendard(12.5, weight: .bold))
                    .foregroundStyle(group.sumIsIncome ? WadeColors.good(scheme) : WadeColors.ink2(scheme))
            }
            .padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(group.rows) { row in
                    Button { editingRecord = try? recordFor(row.id) } label: { rowView(row) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { editingRecord = try? recordFor(row.id) } label: {
                                Label("수정", systemImage: "pencil")
                            }
                            Button(role: .destructive) { pendingDeleteID = row.id } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                    if row.id != group.rows.last?.id {
                        Divider().overlay(WadeColors.line(scheme)).padding(.leading, 16)
                    }
                }
            }
            .background(WadeColors.card(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.listCard, style: .continuous))
            .shadow(color: WadeShadow.list(scheme).color, radius: WadeShadow.list(scheme).radius, y: WadeShadow.list(scheme).y)
        }
        .padding(.bottom, 20)
    }

    private func rowView(_ row: HistoryViewModel.Row) -> some View {
        HStack(spacing: 13) {
            Icon(row.iconName, size: 21).foregroundStyle(Color(hex: row.colorHex))
                .frame(width: 38, height: 38)
                .background(Color(hex: row.colorHex).opacity(0.13), in: RoundedRectangle(cornerRadius: WadeRadius.iconTile))
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name).font(WadeFont.pretendard(14.5, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme)).lineLimit(1)
                Text("\(row.categoryName) · \(row.timeText)").font(WadeFont.pretendard(11.5)).foregroundStyle(WadeColors.ink3(scheme))
            }
            Spacer()
            Text(row.amountText).font(WadeFont.pretendard(15, weight: .heavy))
                .foregroundStyle(row.isIncome ? WadeColors.good(scheme) : WadeColors.ink(scheme))
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }

    private var emptyState: some View {
        VStack(spacing: 11) {
            Icon("receipt_long", size: 38, filled: false).foregroundStyle(WadeColors.ink3(scheme))
                .frame(width: 74, height: 74)
                .background(WadeColors.card2(scheme), in: Circle())
            Text("아직 기록이 없어요").font(WadeFont.pretendard(16, weight: .heavy)).foregroundStyle(WadeColors.ink2(scheme))
            Text("+ 버튼으로 첫 지출을 기록해보세요").font(WadeFont.pretendard(13)).foregroundStyle(WadeColors.ink3(scheme))
        }
        .frame(maxWidth: .infinity).padding(.top, 64)
    }

    private func recordFor(_ id: UUID) throws -> TransactionRecord? {
        try repository?.transactionRecord(id: id)
    }
}
