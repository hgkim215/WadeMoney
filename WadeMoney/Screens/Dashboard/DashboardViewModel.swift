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

    var kind: PeriodKind = .month
    var offset: Int = 0
    private(set) var display: DashboardDisplay?

    init(repository: LedgerRepository, now: Date, calendar: Calendar) {
        self.repository = repository
        self.now = now
        self.calendar = calendar
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
                isOther: slice.isOther
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
            trend: []   // 추세 막대는 Task 6에서 대시보드 화면과 함께 채운다(엔진 월별 합계 조합)
        )
    }
}
