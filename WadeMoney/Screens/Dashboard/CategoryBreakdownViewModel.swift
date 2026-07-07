import Foundation
import Observation
import WadeMoneyCore

@MainActor
@Observable
final class CategoryBreakdownViewModel {
    struct Row: Identifiable {
        let id: UUID
        let categoryID: UUID
        let name: String
        let iconName: String
        let colorHex: String
        let amountText: String
        let percentText: String
    }

    private let repository: LedgerRepository
    private let period: Period
    private(set) var rows: [Row] = []

    init(repository: LedgerRepository, period: Period) {
        self.repository = repository
        self.period = period
    }

    func load() {
        let txns = (try? repository.transactions(from: period.start, to: period.end)) ?? []
        let categories = (try? repository.allCategories(includeArchived: true)) ?? []
        let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        let totals = Aggregator.totalsByCategory(txns, in: period)
        let grandTotal = totals.reduce(Decimal(0)) { $0 + $1.total }

        rows = totals.compactMap { total -> Row? in
            guard let categoryID = total.categoryID, let category = byID[categoryID] else { return nil }
            let pct = grandTotal > 0 ? Int(((total.total / grandTotal).doubleValue * 100).rounded()) : 0
            return Row(
                id: category.id,
                categoryID: category.id,
                name: category.name,
                iconName: category.iconName,
                colorHex: category.colorHex,
                amountText: Won.string(total.total),
                percentText: "\(pct)%"
            )
        }
    }
}
