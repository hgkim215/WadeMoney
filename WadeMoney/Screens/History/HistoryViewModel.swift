import Foundation
import Observation
import WadeMoneyCore

@MainActor
@Observable
final class HistoryViewModel {
    struct FilterChip: Identifiable {
        let id: String
        let label: String
        let filter: HistoryFilter
        let isSelected: Bool
    }
    struct Row: Identifiable {
        let id: UUID
        let name: String
        let iconName: String
        let colorHex: String
        let categoryName: String
        let timeText: String
        let amountText: String
        let isIncome: Bool
        let showsBudgetExcludedLabel: Bool
    }
    struct DayGroup: Identifiable {
        let id: String
        let dateLabel: String
        let tag: String?
        let sumText: String
        let sumIsIncome: Bool
        let rows: [Row]
    }

    private let repository: LedgerRepository
    private let now: Date
    private let calendar: Calendar

    var filter: HistoryFilter = .all
    var searchQuery: String = ""
    private(set) var chips: [FilterChip] = []
    private(set) var groups: [DayGroup] = []

    var isEmpty: Bool { groups.isEmpty }
    var hasSearchQuery: Bool { !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    init(repository: LedgerRepository, now: Date, calendar: Calendar) {
        self.repository = repository
        self.now = now
        self.calendar = calendar
    }

    func load() {
        let categories = (try? repository.allCategories(includeArchived: true)) ?? []
        let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        chips = buildChips(categories: categories)

        let records = ((try? repository.transactions(filter: filter)) ?? [])
            .filter { matchesSearch($0, byID: byID) }
        groups = groupByDay(records, byID: byID)
    }

    private func buildChips(categories: [CategoryRef]) -> [FilterChip] {
        var result: [FilterChip] = [
            FilterChip(id: "all", label: "전체", filter: .all, isSelected: filter == .all)
        ]
        for cat in categories where !cat.isArchived {
            result.append(FilterChip(id: cat.id.uuidString, label: cat.name,
                                     filter: .category(cat.id), isSelected: filter == .category(cat.id)))
        }
        result.append(FilterChip(id: "income", label: "수입", filter: .income, isSelected: filter == .income))
        return result
    }

    private func groupByDay(_ records: [TransactionRecord], byID: [UUID: CategoryRef]) -> [DayGroup] {
        let grouped = Dictionary(grouping: records) { calendar.startOfDay(for: $0.date) }
        let sortedDays = grouped.keys.sorted(by: >)
        return sortedDays.map { day in
            let items = (grouped[day] ?? []).sorted { $0.date > $1.date }
            var expense = Decimal(0), income = Decimal(0)
            for it in items { if it.type == .income { income += it.amount } else { expense += it.amount } }
            // 지출+수입이 섞인 날은 지출 합계만 표시한다(순수 수입만 있는 날에만 +표시). 의도된 동작.
            let sumIsIncome = expense == 0 && income > 0
            let sumText = sumIsIncome ? "+\(Won.string(income))" : "−\(Won.string(expense))"
            return DayGroup(
                id: ISO8601DateFormatter().string(from: day),
                dateLabel: dayLabel(day),
                tag: relativeTag(day),
                sumText: sumText,
                sumIsIncome: sumIsIncome,
                rows: items.map { row($0, byID: byID) }
            )
        }
    }

    private func row(_ r: TransactionRecord, byID: [UUID: CategoryRef]) -> Row {
        let cat = r.categoryID.flatMap { byID[$0] }
        let isIncome = r.type == .income
        let sign = isIncome ? "+" : "−"
        return Row(
            id: r.id,
            name: r.memo?.isEmpty == false ? r.memo! : (isIncome ? "수입" : (cat?.name ?? "기타")),
            iconName: isIncome ? "trending_up" : (cat?.iconName ?? "category"),
            colorHex: isIncome ? "#4E9E6A" : (cat?.colorHex ?? "#A69B8C"),
            categoryName: isIncome ? "수입" : (cat?.name ?? "기타"),
            timeText: timeLabel(r.date),
            amountText: "\(sign)\(Won.string(r.amount))",
            isIncome: isIncome,
            showsBudgetExcludedLabel: !isIncome && r.isExcludedFromBudget
        )
    }

    private func matchesSearch(_ r: TransactionRecord, byID: [UUID: CategoryRef]) -> Bool {
        let rawQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawQuery.isEmpty else { return true }

        let query = rawQuery.lowercased()
        let digits = rawQuery.filter(\.isNumber)
        let category = r.categoryID.flatMap { byID[$0]?.name } ?? (r.type == .income ? "수입" : "기타")
        let memo = r.memo ?? ""
        let type = r.type == .income ? "수입" : "지출"
        let searchableText = [memo, category, type, Won.string(r.amount)]
            .joined(separator: " ")
            .lowercased()

        if searchableText.contains(query) { return true }
        if !digits.isEmpty {
            let amountDigits = Won.string(r.amount).filter(\.isNumber)
            return amountDigits.contains(digits)
        }
        return false
    }

    private func dayLabel(_ day: Date) -> String {
        let c = calendar.dateComponents([.month, .day], from: day)
        return "\(c.month ?? 0)월 \(c.day ?? 0)일"
    }

    private func relativeTag(_ day: Date) -> String? {
        if calendar.isDate(day, inSameDayAs: now) { return "오늘" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)),
           calendar.isDate(day, inSameDayAs: yesterday) { return "어제" }
        return nil
    }

    private func timeLabel(_ date: Date) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}
