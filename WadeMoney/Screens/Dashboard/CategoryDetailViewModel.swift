import Foundation
import Observation
import WadeMoneyCore

@MainActor
@Observable
final class CategoryDetailViewModel {
    struct Row: Identifiable {
        let id: UUID
        let dateText: String
        let memo: String
        let amountText: String
        let showsBudgetExcludedLabel: Bool
    }

    private let repository: LedgerRepository
    private let categoryID: UUID
    private let categoryName: String
    private let period: Period
    private let calendar: Calendar

    private(set) var totalText: String = "0"
    private(set) var percentText: String = "0%"
    private(set) var rows: [Row] = []

    init(
        repository: LedgerRepository,
        categoryID: UUID,
        categoryName: String,
        period: Period,
        calendar: Calendar
    ) {
        self.repository = repository
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.period = period
        self.calendar = calendar
    }

    func load() {
        let txns = (try? repository.transactions(from: period.start, to: period.end)) ?? []
        let totals = Aggregator.totalsByCategory(txns, in: period)
        let grandTotal = totals.reduce(Decimal(0)) { $0 + $1.total }
        let categoryTotal = totals.first { $0.categoryID == categoryID }?.total ?? 0

        totalText = Won.string(categoryTotal)
        percentText = grandTotal > 0
            ? "\(Int(((categoryTotal / grandTotal).doubleValue * 100).rounded()))%"
            : "0%"

        rows = txns
            .filter { $0.type == .expense && $0.categoryID == categoryID }
            .sorted { $0.date != $1.date ? $0.date > $1.date : $0.createdAt > $1.createdAt }
            .map { t in
                Row(
                    id: t.id,
                    dateText: dateLabel(t.date),
                    memo: t.memo?.isEmpty == false ? t.memo! : categoryName,
                    amountText: "\u{2212}\(Won.string(t.amount))",
                    showsBudgetExcludedLabel: t.isExcludedFromBudget
                )
            }
    }

    private func dateLabel(_ date: Date) -> String {
        let c = calendar.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 0)/\(c.day ?? 0)"
    }
}
