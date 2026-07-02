import Foundation
import SwiftData
import WadeMoneyCore

enum HistoryFilter: Equatable {
    case all
    case category(UUID)
    case income
}

@MainActor
final class LedgerRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Reads

    func allCategories(includeArchived: Bool) throws -> [CategoryRef] {
        let models = try context.fetch(
            FetchDescriptor<CategoryModel>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        return models
            .filter { includeArchived || !$0.isArchived }
            .map { $0.toRef() }
    }

    func allTransactions() throws -> [TransactionRecord] {
        try context.fetch(FetchDescriptor<TransactionModel>())
            .map { $0.toRecord() }
    }

    func settingsMonthStartDay() throws -> Int {
        try SettingsStore(context: context).settings().monthStartDay
    }

    // MARK: - Writes

    func addTransaction(
        amount: Decimal,
        type: TransactionKind,
        categoryID: UUID?,
        memo: String?,
        date: Date
    ) throws {
        var category: CategoryModel?
        if let categoryID {
            category = try context.fetch(
                FetchDescriptor<CategoryModel>(predicate: #Predicate { $0.id == categoryID })
            ).first
        }
        context.insert(TransactionModel(
            amount: amount,
            type: type,
            category: category,
            memo: memo,
            date: date,
            createdAt: date
        ))
        try context.save()
    }

    func deleteTransaction(id: UUID) throws {
        if let model = try context.fetch(
            FetchDescriptor<TransactionModel>(predicate: #Predicate { $0.id == id })
        ).first {
            context.delete(model)
            try context.save()
        }
    }

    func transactions(filter: HistoryFilter) throws -> [TransactionRecord] {
        let records = try context.fetch(FetchDescriptor<TransactionModel>())
            .map { $0.toRecord() }
        let filtered: [TransactionRecord]
        switch filter {
        case .all:
            filtered = records
        case .income:
            filtered = records.filter { $0.type == .income }
        case .category(let id):
            filtered = records.filter { $0.type == .expense && $0.categoryID == id }
        }
        return filtered.sorted {
            if $0.date != $1.date { return $0.date > $1.date }
            return $0.createdAt > $1.createdAt
        }
    }

    func transactions(from start: Date, to end: Date) throws -> [TransactionRecord] {
        try context.fetch(
            FetchDescriptor<TransactionModel>(predicate: #Predicate { $0.date >= start && $0.date < end })
        ).map { $0.toRecord() }
    }

    func transactionRecord(id: UUID) throws -> TransactionRecord? {
        try context.fetch(FetchDescriptor<TransactionModel>(predicate: #Predicate { $0.id == id }))
            .first?.toRecord()
    }

    func updateTransaction(
        id: UUID,
        amount: Decimal,
        type: TransactionKind,
        categoryID: UUID?,
        memo: String?,
        date: Date
    ) throws {
        guard let model = try context.fetch(
            FetchDescriptor<TransactionModel>(predicate: #Predicate { $0.id == id })
        ).first else { return }
        var category: CategoryModel?
        if let categoryID {
            category = try context.fetch(
                FetchDescriptor<CategoryModel>(predicate: #Predicate { $0.id == categoryID })
            ).first
        }
        model.amount = amount
        model.type = type
        model.category = type == .income ? nil : category
        model.memo = memo
        model.date = date
        try context.save()
    }

    func totalIncome(in period: Period) throws -> Decimal {
        Aggregator.totalIncome(try allTransactions(), in: period)
    }

    // MARK: - Dashboard

    struct DashboardSummary {
        let period: Period
        let totalExpense: Decimal
        let totalIncome: Decimal
        let budget: Decimal?
        let remaining: Decimal?
        let consumedFraction: Double?
        let pace: PaceResult?
        let donut: [DonutSlice]
        let projected: Decimal?
    }

    func dashboardSummary(
        kind: PeriodKind,
        offset: Int,
        now: Date,
        calendar: Calendar
    ) throws -> DashboardSummary {
        let settingsStore = SettingsStore(context: context)
        let settings = try settingsStore.settings()
        let calc = PeriodCalculator(calendar: calendar, monthStartDay: settings.monthStartDay)
        let period = calc.period(kind, offset: offset, from: now)

        let fetchStart: Date
        switch kind {
        case .day:
            fetchStart = period.start
        case .month, .year:
            fetchStart = calc.previous(period).start
        }
        let txns = try transactions(from: fetchStart, to: period.end)
        let total = Aggregator.totalExpense(txns, in: period)

        let book = try settingsStore.budgetBook()
        let budget: Decimal?
        switch kind {
        case .day:   budget = book.dailyAmount(on: period.start, calc: calc)
        case .month: budget = book.monthlyAmount(on: period.start, calc: calc)
        case .year:  budget = book.yearAmount(on: period.start, calc: calc)
        }

        let remaining = budget.map { $0 - total }
        let consumed: Double? = budget.flatMap { b in
            b > 0 ? (total / b).doubleValue : nil
        }

        // 페이스는 월·연에서만(일 뷰는 일예산 대비로 표시 — 화면 계층).
        let pace: PaceResult? = (kind == .day)
            ? nil
            : PaceCalculator(calc: calc).pace(kind: kind, containing: period.start, asOf: now, txns: txns)

        let donut = Donut.slices(Aggregator.totalsByCategory(txns, in: period), maxSlices: 6)

        let elapsed = calc.daysElapsed(in: period, asOf: now)
        let projected: Decimal? = (kind == .day)
            ? nil
            : Projection.projectedTotal(cumulative: total, daysElapsed: elapsed, daysInPeriod: calc.dayCount(of: period))

        return DashboardSummary(
            period: period,
            totalExpense: total,
            totalIncome: Aggregator.totalIncome(txns, in: period),
            budget: budget,
            remaining: remaining,
            consumedFraction: consumed,
            pace: pace,
            donut: donut,
            projected: projected
        )
    }
}
