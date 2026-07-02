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
            Text("이번 달 예산").font(WadeFont.pretendard(20, weight: .heavy)).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 16)
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
                    .foregroundStyle(amount > 0 ? .white : WadeColors.ink3(scheme))
                    .frame(maxWidth: .infinity).padding(17)
                    .background(amount > 0 ? WadeColors.primary(scheme) : WadeColors.track(scheme),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }.buttonStyle(.plain).disabled(amount <= 0)
        }
        .padding(.horizontal, 20).padding(.bottom, 30)
        .presentationDetents([.medium, .large])
        .background(WadeColors.sheet(scheme))
    }
}
