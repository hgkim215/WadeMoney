import SwiftUI

struct MonthStartDaySheet: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Int
    let onSave: (Int) -> Void

    init(current: Int, onSave: @escaping (Int) -> Void) {
        _selected = State(initialValue: current)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("월 시작일").font(WadeFont.pretendard(20, weight: .heavy))
                Spacer()
                Button { dismiss() } label: {
                    Icon("close", size: 20).foregroundStyle(WadeColors.ink2(scheme))
                }.buttonStyle(.plain)
            }
            .padding(.top, 16)

            Text("지출 집계가 시작되는 매달의 기준일이에요").font(WadeFont.pretendard(12.5)).foregroundStyle(WadeColors.ink3(scheme))

            Picker("월 시작일", selection: $selected) {
                ForEach(1...28, id: \.self) { day in
                    Text("매월 \(day)일").tag(day)
                }
            }
            .pickerStyle(.wheel)

            Button {
                onSave(selected); dismiss()
            } label: {
                Text("저장").font(WadeFont.pretendard(17, weight: .heavy))
                    .foregroundStyle(WadeColors.onPrimary(scheme))
                    .frame(maxWidth: .infinity).padding(17)
                    .background(WadeColors.primary(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.button, style: .continuous))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 20).padding(.bottom, 30)
        .presentationDetents([.medium])
        .background(WadeColors.sheet(scheme))
    }
}
