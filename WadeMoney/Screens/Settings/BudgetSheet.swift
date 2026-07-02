import SwiftUI
import WadeMoneyCore

struct BudgetSheet: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var digits: String
    let onSave: (Decimal) -> Void

    init(current: Decimal, onSave: @escaping (Decimal) -> Void) {
        self._digits = State(initialValue: current > 0 ? "\(NSDecimalNumber(decimal: current).intValue)" : "")
        self.onSave = onSave
    }

    private var amount: Decimal { Decimal(string: digits) ?? 0 }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("이번 달 예산").font(WadeFont.pretendard(20, weight: .heavy))
                Spacer()
                Button { dismiss() } label: {
                    Icon("close", size: 20).foregroundStyle(WadeColors.ink2(scheme))
                }.buttonStyle(.plain)
            }
            .padding(.top, 16)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("₩").font(WadeFont.pretendard(26, weight: .bold))
                Text(digits.isEmpty ? "0" : Won.string(amount)).font(WadeFont.pretendard(52, weight: .heavy))
            }
            .foregroundStyle(amount > 0 ? WadeColors.primary(scheme) : WadeColors.ink3(scheme))
            AmountKeypad(onKey: { key in
                if digits.isEmpty && key.allSatisfy({ $0 == "0" }) { return }
                if digits.count + key.count <= 12 { digits += key }
            }, onBackspace: { if !digits.isEmpty { digits.removeLast() } })
            Button {
                onSave(amount); dismiss()
            } label: {
                Text("예산 저장").font(WadeFont.pretendard(17, weight: .heavy))
                    .foregroundStyle(amount > 0 ? WadeColors.onPrimary(scheme) : WadeColors.ink3(scheme))
                    .frame(maxWidth: .infinity).padding(17)
                    .background(amount > 0 ? WadeColors.primary(scheme) : WadeColors.track(scheme),
                                in: RoundedRectangle(cornerRadius: WadeRadius.button, style: .continuous))
            }.buttonStyle(.plain).disabled(amount <= 0)
        }
        .padding(.horizontal, WadeSpacing.screenH).padding(.bottom, 34)
        .presentationDetents([.medium, .large])
        .background(WadeColors.sheet(scheme))
    }
}
