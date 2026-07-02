import WidgetKit
import SwiftUI
import SwiftData

struct LockScreenEntry: TimelineEntry {
    let date: Date
    let data: WidgetDataBuilder.LockScreenData
}

struct LockScreenProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScreenEntry {
        LockScreenEntry(date: Date(), data: .init(consumedFraction: 0.42, remainingText: "840,000원"))
    }
    func getSnapshot(in context: Context, completion: @escaping @Sendable (LockScreenEntry) -> Void) {
        completion(placeholder(in: context))
    }
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<LockScreenEntry>) -> Void) {
        Task { @MainActor in
            let container = WidgetPersistence.makeContainer()
            let repo = LedgerRepository(context: container.mainContext)
            let now = Date()
            let data = WidgetDataBuilder.lockScreenBudget(repository: repo, now: now, calendar: .current)
            let next = Calendar.current.date(byAdding: .hour, value: 4, to: now) ?? now.addingTimeInterval(4 * 3600)
            completion(Timeline(entries: [LockScreenEntry(date: now, data: data)], policy: .after(next)))
        }
    }
}

struct LockScreenBudgetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LockScreenEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                Gauge(value: min(1, entry.data.consumedFraction ?? 0)) {
                    Icon("savings", size: 12)
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .widgetAccentable()
            case .accessoryInline:
                Text(entry.data.remainingText.map { "남은 예산 \($0)" } ?? "예산 미설정")
            default:
                EmptyView()
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

struct LockScreenBudgetWidget: Widget {
    let kind = "WadeMoneyLockScreenBudgetWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenProvider()) { entry in
            LockScreenBudgetWidgetView(entry: entry)
        }
        .configurationDisplayName("남은 예산")
        .description("이달 남은 예산을 잠금화면에서 바로 봐요.")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

#Preview(as: .accessoryCircular) {
    LockScreenBudgetWidget()
} timeline: {
    LockScreenEntry(date: .now, data: .init(consumedFraction: 0.42, remainingText: "840,000원"))
}
