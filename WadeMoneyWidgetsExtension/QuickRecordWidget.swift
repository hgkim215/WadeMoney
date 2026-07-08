import WidgetKit
import SwiftUI
import SwiftData

struct QuickRecordEntry: TimelineEntry {
    let date: Date
    let chips: [WidgetDataBuilder.ChipData]
}

struct QuickRecordProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickRecordEntry {
        QuickRecordEntry(date: Date(), chips: [])
    }
    func getSnapshot(in context: Context, completion: @escaping @Sendable (QuickRecordEntry) -> Void) {
        completion(placeholder(in: context))
    }
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<QuickRecordEntry>) -> Void) {
        Task { @MainActor in
            let chips: [WidgetDataBuilder.ChipData]
            if let container = WidgetPersistence.shared {
                let repo = LedgerRepository(context: container.mainContext)
                chips = WidgetDataBuilder.quickRecordChips(repository: repo)
            } else {
                chips = []
            }
            let now = Date()
            let next = Calendar.current.date(byAdding: .hour, value: 12, to: now) ?? now.addingTimeInterval(12 * 3600)
            completion(Timeline(entries: [QuickRecordEntry(date: now, chips: chips)], policy: .after(next)))
        }
    }
}

struct QuickRecordWidgetView: View {
    @Environment(\.colorScheme) private var scheme
    let entry: QuickRecordEntry

    var body: some View {
        HStack(spacing: 8) {
            ForEach(entry.chips) { chip in
                Link(destination: DeepLink.quickAdd(categoryID: chip.id)) {
                    chipLabel(icon: chip.iconName, name: chip.name, tint: Color(hex: chip.colorHex))
                }
            }
            Link(destination: DeepLink.quickAdd(categoryID: nil)) {
                chipLabel(icon: "add", name: "직접", tint: WadeColors.ink2(scheme))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(WadeColors.card(scheme), for: .widget)
    }

    private func chipLabel(icon: String, name: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Icon(icon, size: 18).foregroundStyle(tint)
            Text(name).font(WadeFont.pretendard(10, weight: .bold)).foregroundStyle(WadeColors.ink(scheme))
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickRecordWidget: Widget {
    let kind = "WadeMoneyQuickRecordWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickRecordProvider()) { entry in
            QuickRecordWidgetView(entry: entry)
        }
        .configurationDisplayName("빠른 기록")
        .description("카테고리를 탭해 바로 지출 입력 화면으로 이동해요.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    QuickRecordWidget()
} timeline: {
    QuickRecordEntry(date: .now, chips: [
        .init(id: UUID(), name: "식비", iconName: "restaurant", colorHex: "#E28A4E"),
        .init(id: UUID(), name: "카페", iconName: "local_cafe", colorHex: "#C4924E"),
        .init(id: UUID(), name: "교통", iconName: "directions_bus", colorHex: "#6F9FD8"),
    ])
}
