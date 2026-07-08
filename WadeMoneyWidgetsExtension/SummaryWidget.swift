import WidgetKit
import SwiftUI
import SwiftData

struct SummaryEntry: TimelineEntry {
    let date: Date
    let data: WidgetDataBuilder.SummaryData
}

struct SummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> SummaryEntry {
        SummaryEntry(date: Date(), data: .init(todayExpenseText: "12,000", monthRemainingText: "840,000원 남음", consumedFraction: 0.42))
    }
    func getSnapshot(in context: Context, completion: @escaping @Sendable (SummaryEntry) -> Void) {
        completion(placeholder(in: context))
    }
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<SummaryEntry>) -> Void) {
        Task { @MainActor in
            let now = Date()
            let data: WidgetDataBuilder.SummaryData
            if let container = WidgetPersistence.shared {
                let repo = LedgerRepository(context: container.mainContext)
                data = WidgetDataBuilder.summary(repository: repo, now: now, calendar: .current)
            } else {
                data = .init(todayExpenseText: "0", monthRemainingText: nil, consumedFraction: nil)
            }
            let next = Calendar.current.date(byAdding: .hour, value: 4, to: now) ?? now.addingTimeInterval(4 * 3600)
            completion(Timeline(entries: [SummaryEntry(date: now, data: data)], policy: .after(next)))
        }
    }
}

struct SummaryWidgetView: View {
    @Environment(\.colorScheme) private var scheme
    let entry: SummaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("오늘 지출").font(WadeFont.pretendard(11, weight: .semibold)).foregroundStyle(WadeColors.ink3(scheme))
            Text("₩\(entry.data.todayExpenseText)").font(WadeFont.pretendard(22, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
            if let frac = entry.data.consumedFraction {
                ProgressView(value: min(1, frac)).tint(WadeColors.primary(scheme))
            }
            if let remain = entry.data.monthRemainingText {
                Text("이달 예산 \(remain)").font(WadeFont.pretendard(10.5)).foregroundStyle(WadeColors.ink3(scheme))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(WadeColors.card(scheme), for: .widget)
    }
}

struct SummaryWidget: Widget {
    let kind = "WadeMoneySummaryWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SummaryProvider()) { entry in
            SummaryWidgetView(entry: entry)
        }
        .configurationDisplayName("오늘 지출 요약")
        .description("오늘 지출과 이달 예산 잔액을 한눈에 봐요.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    SummaryWidget()
} timeline: {
    SummaryEntry(date: .now, data: .init(todayExpenseText: "12,000", monthRemainingText: "840,000원 남음", consumedFraction: 0.42))
}
