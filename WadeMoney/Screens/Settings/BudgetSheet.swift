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
        // 키패드+저장 버튼까지 합친 높이가 .medium 디텐트나 작은 화면·큰 Dynamic Type에서
        // 잘릴 수 있어 ScrollView로 감싼다(QuickAddSheet와 동일한 방식).
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Text("이번 달 예산").font(WadeFont.pretendard(20, weight: .heavy))
                    Spacer()
                    Button { dismiss() } label: {
                        Icon("close", size: 20).foregroundStyle(WadeColors.ink2(scheme))
                    }.buttonStyle(.plain)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("₩").font(WadeFont.pretendard(26, weight: .bold))
                    // 금액은 절대 말줄임하지 않는다 — 자리수가 커지면 글자를 줄여 전 구간을 보여준다.
                    Text(digits.isEmpty ? "0" : Won.string(amount)).font(WadeFont.pretendard(52, weight: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
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
                Button {
                    onSave(0); dismiss()
                } label: {
                    Text("예산 설정 안 함").font(WadeFont.pretendard(13.5, weight: .bold))
                        .foregroundStyle(WadeColors.ink3(scheme))
                }.buttonStyle(.plain).padding(.top, 2)
            }
            .padding(.horizontal, WadeSpacing.screenH)
            .padding(.top, WadeSpacing.sheetTop)
            .padding(.bottom, WadeSpacing.sheetBottom)
        }
        .presentationDetents([.height(520), .large])
        .background(WadeColors.sheet(scheme))
    }
}
