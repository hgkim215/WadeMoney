import Foundation
import Observation
import WadeMoneyCore

@MainActor
@Observable
final class AIReportViewModel {
    struct CategoryChange: Equatable, Identifiable {
        let id: UUID
        let name: String
        let iconName: String
        let colorHex: String
        let percentText: String
        let increased: Bool
    }
    struct Display: Equatable {
        let monthLabel: String
        let monthShortLabel: String
        let daysElapsedText: String
        let totalText: String
        let tag: String
        let isGood: Bool
        let summarySentence: String?
        let projectedText: String?
        let overBudgetText: String?
        let changes: [CategoryChange]
        let tipSentence: String?
    }

    private let repository: LedgerRepository
    private let now: Date
    private let calendar: Calendar
    private let narrator: ReportNarrating
    private let aiAvailability: AIAvailabilityChecking

    private(set) var display: Display?
    private(set) var isLoading = false

    init(
        repository: LedgerRepository, now: Date, calendar: Calendar,
        narrator: ReportNarrating = FoundationModelsReportNarrator(),
        aiAvailability: AIAvailabilityChecking = SystemLanguageModelAvailability()
    ) {
        self.repository = repository
        self.now = now
        self.calendar = calendar
        self.narrator = narrator
        self.aiAvailability = aiAvailability
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard
            let summary = try? repository.dashboardSummary(kind: .month, offset: 0, now: now, calendar: calendar),
            let categories = try? repository.allCategories(includeArchived: true),
            let txns = try? repository.allTransactions(),
            let monthStartDay = try? repository.settingsMonthStartDay()
        else {
            display = nil
            return
        }

        let calc = PeriodCalculator(calendar: calendar, monthStartDay: monthStartDay)
        let elapsed = calc.daysElapsed(in: summary.period, asOf: now)
        let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        let categoryPace = PaceCalculator(calc: calc).categoryPace(kind: .month, containing: now, asOf: now, txns: txns)
        let changes: [CategoryChange] = categoryPace.compactMap { item in
            guard let cid = item.categoryID, let ratio = item.deltaRatio, let cat = byID[cid] else { return nil }
            let pct = Int((abs(ratio) * 100).doubleValue.rounded())
            return CategoryChange(id: cid, name: cat.name, iconName: cat.iconName, colorHex: cat.colorHex,
                                   percentText: "\(pct)%", increased: ratio > 0)
        }

        let increased = (summary.pace?.deltaRatio).map { $0 > 0 } ?? false
        let isGood = !increased
        let overBudget: Decimal? = {
            guard let budget = summary.budget, let projected = summary.projected, projected > budget else { return nil }
            return projected - budget
        }()

        let topIncrease = changes.first { $0.increased }
        let topDecrease = changes.first { !$0.increased }
        let monthLabel = PeriodLabel.text(kind: .month, period: summary.period, now: now, calendar: calendar)
        let monthComponent = calendar.component(.month, from: summary.period.start)

        let input = ReportInput(
            monthLabel: monthLabel,
            daysElapsedText: "\(elapsed)일",
            totalExpenseText: Won.string(summary.totalExpense),
            budgetStatusText: overBudget != nil ? "예산 초과 예상 +\(Won.string(overBudget!))원" : "예산 내 예상",
            paceDeltaPercentText: summary.pace?.deltaRatio.map { "\(Int((abs($0) * 100).doubleValue.rounded()))%" } ?? "0%",
            paceIncreased: increased,
            projectedTotalText: summary.projected.map { Won.string($0) } ?? "-",
            topIncrease: topIncrease.map { (name: $0.name, percentText: $0.percentText) },
            topDecrease: topDecrease.map { (name: $0.name, percentText: $0.percentText) }
        )

        let aiOn = aiAvailability.isAvailable && (try? repository.aiEnabled()) == true
        let narration = aiOn ? try? await narrator.narrate(input) : nil

        display = Display(
            monthLabel: monthLabel,
            monthShortLabel: "\(monthComponent)월",
            daysElapsedText: input.daysElapsedText,
            totalText: input.totalExpenseText,
            tag: isGood ? "양호" : "주의",
            isGood: isGood,
            summarySentence: narration?.summarySentence,
            projectedText: summary.projected.map { Won.string($0) },
            overBudgetText: overBudget.map { "+\(Won.string($0))원" },
            changes: changes,
            tipSentence: narration?.tipSentence
        )
    }
}
