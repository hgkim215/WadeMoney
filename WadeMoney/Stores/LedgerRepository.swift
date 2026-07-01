import Foundation
import SwiftData
import WadeMoneyCore

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

    // MARK: - Dashboard

    struct DashboardSummary {
        let period: Period
        let totalExpense: Decimal
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
        let settings = try SettingsStore(context: context).settings()
        let calc = PeriodCalculator(calendar: calendar, monthStartDay: settings.monthStartDay)
        let period = calc.period(kind, offset: offset, from: now)

        let txns = try allTransactions()
        let total = Aggregator.totalExpense(txns, in: period)

        let book = try SettingsStore(context: context).budgetBook()
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
            budget: budget,
            remaining: remaining,
            consumedFraction: consumed,
            pace: pace,
            donut: donut,
            projected: projected
        )
    }
}
