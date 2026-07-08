import SwiftUI

struct NotificationTimeSheet: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Date
    let onSave: (Int, Int) -> Void

    init(hour: Int, minute: Int, onSave: @escaping (Int, Int) -> Void) {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        _selected = State(initialValue: Calendar.current.date(from: comps) ?? Date())
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("알림 시각").font(WadeFont.pretendard(20, weight: .heavy))
                Spacer()
                Button { dismiss() } label: {
                    Icon("close", size: 20).foregroundStyle(WadeColors.ink2(scheme))
                }.buttonStyle(.plain)
            }

            Text("매일 이 시각에 오늘 지출을 기록했는지 알려드려요").font(WadeFont.pretendard(12.5)).foregroundStyle(WadeColors.ink3(scheme))

            DatePicker("알림 시각", selection: $selected, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()

            Button {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: selected)
                onSave(comps.hour ?? 22, comps.minute ?? 0)
                dismiss()
            } label: {
                Text("저장").font(WadeFont.pretendard(17, weight: .heavy))
                    .foregroundStyle(WadeColors.onPrimary(scheme))
                    .frame(maxWidth: .infinity).padding(17)
                    .background(WadeColors.primary(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.button, style: .continuous))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, WadeSpacing.screenH)
        .padding(.top, WadeSpacing.sheetTop)
        .padding(.bottom, WadeSpacing.sheetBottom)
        .presentationDetents([.medium])
        .background(WadeColors.sheet(scheme))
    }
}
