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
        /// 전체 기간 통틀어 거래가 하나도 없어 즉시(하드) 삭제가 가능한지.
        let canDelete: Bool
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
        // 삭제 가능 여부는 이번 달이 아니라 전체 기간 기준이어야 한다(과거 거래가 있으면 삭제 불가).
        let everUsedIDs = Set(txns.compactMap(\.categoryID))

        func item(_ ref: CategoryRef) -> Item {
            let used = totals[ref.id] ?? 0
            let usage = used > 0 ? "이번 달 \(Won.string(used))원" : "이번 달 사용 없음"
            return Item(id: ref.id, name: ref.name, iconName: ref.iconName, colorHex: ref.colorHex,
                       usageText: usage, canDelete: !everUsedIDs.contains(ref.id))
        }
        activeItems = ((try? categoryStore.active()) ?? []).map(item)
        archivedItems = ((try? categoryStore.archived()) ?? []).map(item)
    }

    /// 편집 시트의 저장 버튼 활성화 판단용. `excluding`은 수정 중인 자기 자신.
    func isNameTaken(_ name: String, excluding: UUID? = nil) -> Bool {
        categoryStore.isNameTaken(name, excluding: excluding)
    }

    func add(name: String, iconName: String, colorHex: String) {
        try? categoryStore.add(name: name, iconName: iconName, colorHex: colorHex); load()
    }
    func update(id: UUID, name: String, iconName: String, colorHex: String) {
        try? categoryStore.update(id: id, name: name, iconName: iconName, colorHex: colorHex); load()
    }
    func archive(id: UUID) { try? categoryStore.archive(id: id); load() }
    func restore(id: UUID) { try? categoryStore.restore(id: id); load() }
    func delete(id: UUID) { try? categoryStore.delete(id: id); load() }

    func move(from source: IndexSet, to destination: Int) {
        activeItems.move(fromOffsets: source, toOffset: destination)
        try? categoryStore.reorder(activeItems.map(\.id))
    }
}
