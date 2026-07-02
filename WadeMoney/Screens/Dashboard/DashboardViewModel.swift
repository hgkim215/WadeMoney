import Foundation
import Observation
import WadeMoneyCore

@MainActor
@Observable
final class DashboardViewModel {
    enum PaceDirection { case up, down }

    struct PaceBadge: Equatable {
        let deltaText: String       // 예: "12%"
        let direction: PaceDirection
        let note: String            // 예: "지난달 같은 시점보다"
    }
    struct DayBudgetInfo: Equatable {
        let dayBudgetText: String
        let remainText: String
    }
    struct DonutLegendItem: Equatable, Identifiable {
        let id: String
        let categoryID: UUID?
        let name: String
        let colorHex: String
        let percentText: String
        let isOther: Bool
        let fraction: Double
    }
    struct TrendBar: Equatable, Identifiable {
        let id: Int
        let label: String
        let valueText: String
        let heightFraction: Double
        let isCurrent: Bool
    }
    struct DashboardDisplay: Equatable {
        let periodLabel: String
        let scopeText: String
        let totalText: String
        let budgetText: String?
        let remainText: String?
        let consumedPercentText: String?
        let consumedFraction: Double?
        let pace: PaceBadge?
        let dayBudget: DayBudgetInfo?
        let donut: [DonutLegendItem]
        let trend: [TrendBar]
    }

    private let repository: LedgerRepository
    private let now: Date
    private let calendar: Calendar
    private let aiAvailability: AIAvailabilityChecking
    private let insightGenerator: InsightGenerating

    var kind: PeriodKind = .month
    var offset: Int = 0
    private(set) var display: DashboardDisplay?
    private(set) var insightText: String?
    private(set) var insightIsGood: Bool?
    private(set) var isLoadingInsight = false
    private var insightTask: Task<Void, Never>?

    init(
        repository: LedgerRepository, now: Date, calendar: Calendar,
        aiAvailability: AIAvailabilityChecking = SystemLanguageModelAvailability(),
        insightGenerator: InsightGenerating = FoundationModelsInsightGenerator()
    ) {
        self.repository = repository
        self.now = now
        self.calendar = calendar
        self.aiAvailability = aiAvailability
        self.insightGenerator = insightGenerator
    }

    func load() {
        do {
            let summary = try repository.dashboardSummary(kind: kind, offset: offset, now: now, calendar: calendar)
            let categories = try repository.allCategories(includeArchived: true)
            display = build(summary, categories: categories)
        } catch {
            display = nil
        }
    }

    func refreshInsight() async {
        insightTask?.cancel()

        guard
            let d = display, let pace = d.pace,
            aiAvailability.isAvailable,
            (try? repository.aiEnabled()) == true
        else {
            insightTask = nil
            insightText = nil
            return
        }
        let top = d.donut.first { !$0.isOther }
        let input = InsightInput(
            periodLabel: d.periodLabel,
            totalExpenseText: d.totalText,
            paceDeltaPercentText: pace.deltaText,
            paceIncreased: pace.direction == .up,
            topCategoryName: top?.name,
            topCategoryPercentText: top?.percentText
        )
        isLoadingInsight = true
        let task = Task { [insightGenerator] in
            let result: Result<String, Error>
            do {
                result = .success(try await insightGenerator.generate(input))
            } catch {
                result = .failure(error)
            }
            // A newer refreshInsight() call may have superseded this one while we
            // were suspended above — discard the result instead of overwriting
            // state for a period that's no longer displayed.
            guard !Task.isCancelled else { return }
            switch result {
            case .success(let sentence):
                self.insightText = sentence
                self.insightIsGood = pace.direction == .down
            case .failure:
                self.insightText = nil
                self.insightIsGood = nil
            }
            self.isLoadingInsight = false
        }
        insightTask = task
        await task.value
    }

    private func build(_ s: LedgerRepository.DashboardSummary, categories: [CategoryRef]) -> DashboardDisplay {
        let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        let pace: PaceBadge? = s.pace.flatMap { p in
            guard let ratio = p.deltaRatio else { return nil }
            let pct = Int((abs(ratio) * 100).doubleValue.rounded())
            let up = ratio > 0
            let note = kind == .year ? "작년 같은 시점보다" : "지난달 같은 시점보다"
            return PaceBadge(deltaText: "\(pct)%", direction: up ? .up : .down, note: note)
        }

        let dayBudget: DayBudgetInfo? = (kind == .day)
            ? s.budget.map { b in
                DayBudgetInfo(dayBudgetText: Won.string(b),
                              remainText: Won.string((b - s.totalExpense)))
              }
            : nil

        let legend: [DonutLegendItem] = s.donut.map { slice in
            let name = slice.isOther ? "기타" : (slice.categoryID.flatMap { byID[$0]?.name } ?? "기타")
            let color = slice.isOther ? "#A69B8C" : (slice.categoryID.flatMap { byID[$0]?.colorHex } ?? "#A69B8C")
            let pct = Int((slice.fraction * 100).rounded())
            return DonutLegendItem(
                id: slice.categoryID?.uuidString ?? "other",
                categoryID: slice.categoryID,
                name: name,
                colorHex: color,
                percentText: "\(pct)%",
                isOther: slice.isOther,
                fraction: slice.fraction
            )
        }

        let scope: String = {
            switch kind {
            case .day: return "오늘 지출"
            case .month: return "이번 달 총지출"
            case .year: return "올해 총지출"
            }
        }()

        return DashboardDisplay(
            periodLabel: PeriodLabel.text(kind: kind, period: s.period, now: now, calendar: calendar),
            scopeText: scope,
            totalText: Won.string(s.totalExpense),
            budgetText: s.budget.map { Won.string($0) },
            remainText: s.remaining.map { Won.string($0) },
            consumedPercentText: s.consumedFraction.map { "\(Int(($0 * 100).rounded()))%" },
            consumedFraction: s.consumedFraction,
            pace: pace,
            dayBudget: dayBudget,
            donut: legend,
            trend: buildTrend(currentPeriodStart: s.period.start)
        )
    }

    private func buildTrend(currentPeriodStart: Date) -> [TrendBar] {
        let calc = periodCalculator()
        let count: Int
        switch kind {
        case .day: count = 7
        case .month: count = 6
        case .year: count = 12
        }
        let txns = (try? repository.allTransactions()) ?? []
        var raw: [(label: String, value: Decimal, isCurrent: Bool)] = []
        for i in stride(from: count - 1, through: 0, by: -1) {
            let p = calc.period(kind, offset: offset - i, from: now)
            let total = Aggregator.totalExpense(txns, in: p)
            raw.append((label: barLabel(for: p), value: total, isCurrent: i == 0))
        }
        let maxV = raw.map(\.value).max() ?? 0
        return raw.enumerated().map { idx, r in
            let frac = maxV > 0 ? (r.value / maxV).doubleValue : 0
            return TrendBar(id: idx, label: r.label, valueText: Won.string(r.value),
                            heightFraction: frac, isCurrent: r.isCurrent)
        }
    }

    private func periodCalculator() -> PeriodCalculator {
        let monthStartDay = (try? repository.settingsMonthStartDay()) ?? 1
        return PeriodCalculator(calendar: calendar, monthStartDay: monthStartDay)
    }

    private func barLabel(for p: Period) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: p.start)
        switch kind {
        case .day: return "\(c.day ?? 0)"
        case .month: return "\(c.month ?? 0)월"
        case .year: return "\(c.year ?? 0)"
        }
    }
}
