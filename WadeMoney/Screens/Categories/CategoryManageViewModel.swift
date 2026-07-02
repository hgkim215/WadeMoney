import Foundation
import Observation
import WadeMoneyCore

@MainActor
@Observable
final class CategoryManageViewModel {
    struct Item: Identifiable {
        let id: UUID
        let name: String
        let iconName: String
        let colorHex: String
        let usageText: String
    }

    private let categoryStore: CategoryStore
    private let repository: LedgerRepository
    private let now: Date
    private let calendar: Calendar

    private(set) var activeItems: [Item] = []
    private(set) var archivedItems: [Item] = []

    init(categoryStore: CategoryStore, repository: LedgerRepository, now: Date, calendar: Calendar) {
        self.categoryStore = categoryStore
        self.repository = repository
        self.now = now
        self.calendar = calendar
    }

    func load() {
        let settings = (try? repository.settingsMonthStartDay()) ?? 1
        let calc = PeriodCalculator(calendar: calendar, monthStartDay: settings)
        let month = calc.period(.month, containing: now)
        let txns = (try? repository.allTransactions()) ?? []
        let totals = Dictionary(grouping: txns.filter { $0.type == .expense && $0.date >= month.start && $0.date < month.end },
                                by: { $0.categoryID })
            .mapValues { $0.reduce(Decimal(0)) { $0 + $1.amount } }

        func item(_ ref: CategoryRef) -> Item {
            let used = totals[ref.id] ?? 0
            let usage = used > 0 ? "이번 달 \(Won.string(used))원" : "이번 달 사용 없음"
            return Item(id: ref.id, name: ref.name, iconName: ref.iconName, colorHex: ref.colorHex, usageText: usage)
        }
        activeItems = ((try? categoryStore.active()) ?? []).map(item)
        archivedItems = ((try? categoryStore.archived()) ?? []).map(item)
    }

    func add(name: String, iconName: String, colorHex: String) {
        try? categoryStore.add(name: name, iconName: iconName, colorHex: colorHex); load()
    }
    func update(id: UUID, name: String, iconName: String, colorHex: String) {
        try? categoryStore.update(id: id, name: name, iconName: iconName, colorHex: colorHex); load()
    }
    func archive(id: UUID) { try? categoryStore.archive(id: id); load() }
    func restore(id: UUID) { try? categoryStore.restore(id: id); load() }

    func move(from source: IndexSet, to destination: Int) {
        var ids = activeItems.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        try? categoryStore.reorder(ids); load()
    }
}
