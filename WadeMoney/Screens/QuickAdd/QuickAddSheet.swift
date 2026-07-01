import SwiftUI
import SwiftData
import WadeMoneyCore

struct QuickAddSheet: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var vm: QuickAddViewModel?
    let onSaved: () -> Void

    private let keys = ["1","2","3","4","5","6","7","8","9","00","0","←"]

    var body: some View {
        Group {
            if let vm { content(vm) }
        }
        .onAppear {
            if vm == nil { vm = QuickAddViewModel(repository: LedgerRepository(context: modelContext)) }
        }
        .presentationDetents([.large])
        .background(WadeColors.sheet(scheme))
    }

    @ViewBuilder private func content(_ vm: QuickAddViewModel) -> some View {
        VStack(spacing: 14) {
            HStack {
                Text(vm.type == .income ? "새 수입" : "새 지출").font(WadeFont.pretendard(20, weight: .heavy))
                Spacer()
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

            TextField("메모 (선택)", text: Binding(get: { vm.memo }, set: { vm.memo = $0 }))
                .font(WadeFont.pretendard(14.5))
                .padding(13)
                .background(WadeColors.card2(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.segment))

            keypad(vm)

            Button {
                try? vm.save(date: Date())
                onSaved(); dismiss()
            } label: {
                HStack(spacing: 6) { Icon("check", size: 22); Text("저장하기").font(WadeFont.pretendard(17, weight: .heavy)) }
                    .foregroundStyle(vm.canSave ? .white : WadeColors.ink3(scheme))
                    .frame(maxWidth: .infinity).padding(17)
                    .background(vm.canSave ? WadeColors.primary(scheme) : WadeColors.track(scheme),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain).disabled(!vm.canSave)
        }
        .padding(.horizontal, 20).padding(.bottom, 30)
    }

    private func typeToggle(_ vm: QuickAddViewModel) -> some View {
        HStack(spacing: 3) {
            ForEach([TransactionKind.expense, .income], id: \.self) { t in
                Button { vm.type = t } label: {
                    Text(t == .expense ? "지출" : "수입")
                        .font(WadeFont.pretendard(12.5, weight: .bold))
                        .foregroundStyle(vm.type == t ? .white : WadeColors.ink2(scheme))
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

    private func keypad(_ vm: QuickAddViewModel) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 9) {
            ForEach(keys, id: \.self) { key in
                Button {
                    if key == "←" { vm.backspace() } else { vm.tapKey(key) }
                } label: {
                    Group {
                        if key == "←" { Icon("backspace", size: 26).foregroundStyle(WadeColors.ink2(scheme)) }
                        else { Text(key).font(WadeFont.pretendard(24, weight: .bold)).foregroundStyle(WadeColors.ink(scheme)) }
                    }
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(WadeColors.card2(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.control))
                }.buttonStyle(.plain)
            }
        }
    }
}
