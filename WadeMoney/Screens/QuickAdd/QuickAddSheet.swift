import SwiftUI
import SwiftData
import WadeMoneyCore

struct QuickAddSheet: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var vm: QuickAddViewModel?
    let onSaved: () -> Void
    var editing: TransactionRecord? = nil
    var preselectedCategoryID: UUID? = nil

    var body: some View {
        Group {
            if let vm { content(vm) }
        }
        .onAppear {
            if vm == nil {
                vm = QuickAddViewModel(repository: LedgerRepository(context: modelContext), editing: editing, preselectedCategoryID: preselectedCategoryID)
            }
        }
        .presentationDetents([.large])
        .background(WadeColors.sheet(scheme))
    }

    @ViewBuilder private func content(_ vm: QuickAddViewModel) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Button { dismiss() } label: {
                        Icon("close", size: 20).foregroundStyle(WadeColors.ink2(scheme))
                    }.buttonStyle(.plain)
                    Text(vm.isEditing
                         ? (vm.type == .income ? "수입 수정" : "지출 수정")
                         : (vm.type == .income ? "새 수입" : "새 지출"))
                        .font(WadeFont.pretendard(20, weight: .heavy))
                    Spacer()
                    if vm.isEditing {
                        Button {
                            try? vm.delete()
                            onSaved()
                            dismiss()
                        } label: {
                            Icon("delete", size: 20).foregroundStyle(WadeColors.bad(scheme))
                        }.buttonStyle(.plain).padding(.trailing, 10)
                    }
                    typeToggle(vm)
                }
                .padding(.top, 16)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("₩").font(WadeFont.pretendard(26, weight: .bold))
                    Text(vm.amountDigits.isEmpty ? "0" : Won.string(vm.amountDecimal))
                        .font(WadeFont.pretendard(52, weight: .heavy))
                }
                .foregroundStyle(vm.amountDecimal > 0
                    ? (vm.type == .income ? WadeColors.good(scheme) : WadeColors.ink(scheme))
                    : WadeColors.ink3(scheme))

                if vm.type == .expense { categoryGrid(vm) }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        TextField("메모 (선택)", text: Binding(get: { vm.memo }, set: { vm.memo = $0 }))
                            .font(WadeFont.pretendard(14.5))
                        if vm.showsPolishButton || vm.hasPolished {
                            Button {
                                Task { await vm.polishMemo() }
                            } label: {
                                HStack(spacing: 4) {
                                    if vm.isPolishing {
                                        ProgressView().controlSize(.mini)
                                    } else {
                                        Icon("auto_awesome", size: 14)
                                    }
                                    Text(vm.hasPolished ? "정리됨" : "AI 다듬기").font(WadeFont.pretendard(11.5, weight: .bold))
                                }
                                .foregroundStyle(WadeColors.primary(scheme))
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(WadeColors.aitint2(scheme), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(vm.isPolishing || vm.hasPolished)
                        }
                    }
                    .padding(13)
                    .background(WadeColors.card2(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.segment))

                    if let note = vm.polishNote {
                        Text(note).font(WadeFont.pretendard(11.5)).foregroundStyle(WadeColors.primary(scheme))
                    }
                }

                AmountKeypad(onKey: { vm.tapKey($0) }, onBackspace: { vm.backspace() })

                Button {
                    do {
                        try vm.save(date: Date())
                        onSaved()
                        dismiss()
                    } catch {
                        // 저장 실패 시 시트를 닫지 않는다(성공을 가장하지 않음). 오류 토스트는 후속.
                    }
                } label: {
                    HStack(spacing: 6) { Icon("check", size: 22); Text("저장하기").font(WadeFont.pretendard(17, weight: .heavy)) }
                        .foregroundStyle(vm.canSave ? WadeColors.onPrimary(scheme) : WadeColors.ink3(scheme))
                        .frame(maxWidth: .infinity).padding(17)
                        .background(vm.canSave ? WadeColors.primary(scheme) : WadeColors.track(scheme),
                                    in: RoundedRectangle(cornerRadius: WadeRadius.button, style: .continuous))
                }
                .buttonStyle(.plain).disabled(!vm.canSave)
            }
            .padding(.horizontal, 20).padding(.bottom, 30)
        }
    }

    private func typeToggle(_ vm: QuickAddViewModel) -> some View {
        HStack(spacing: 3) {
            ForEach([TransactionKind.expense, .income], id: \.self) { t in
                Button { vm.type = t } label: {
                    Text(t == .expense ? "지출" : "수입")
                        .font(WadeFont.pretendard(12.5, weight: .bold))
                        .foregroundStyle(vm.type == t ? WadeColors.onPrimary(scheme) : WadeColors.ink2(scheme))
                        .padding(.horizontal, 15).padding(.vertical, 7)
                        .background(vm.type == t ? (t == .income ? WadeColors.good(scheme) : WadeColors.primary(scheme)) : .clear,
                                    in: Capsule())
                }.buttonStyle(.plain)
            }
        }
        .padding(3).background(WadeColors.card2(scheme), in: Capsule())
    }

    private func categoryGrid(_ vm: QuickAddViewModel) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(vm.categories) { cat in
                let sel = vm.selectedCategoryID == cat.id
                Button { vm.selectedCategoryID = cat.id } label: {
                    VStack(spacing: 6) {
                        Icon(cat.iconName, size: 21).foregroundStyle(Color(hex: cat.colorHex))
                            .frame(width: 38, height: 38)
                            .background(Color(hex: cat.colorHex).opacity(0.13), in: RoundedRectangle(cornerRadius: WadeRadius.iconTile))
                        Text(cat.name).font(WadeFont.pretendard(11.5, weight: .bold))
                            .foregroundStyle(sel ? WadeColors.primary(scheme) : WadeColors.ink2(scheme))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(sel ? WadeColors.primarysoft(scheme) : WadeColors.card2(scheme),
                                in: RoundedRectangle(cornerRadius: WadeRadius.control))
                    .overlay(RoundedRectangle(cornerRadius: WadeRadius.control)
                        .stroke(sel ? WadeColors.primary(scheme) : .clear, lineWidth: 2))
                }.buttonStyle(.plain)
            }
        }
    }
}
