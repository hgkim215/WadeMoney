import Foundation
import Observation
import WadeMoneyCore

@MainActor
@Observable
final class QuickAddViewModel {
    private let repository: LedgerRepository

    var amountDigits: String = ""
    var type: TransactionKind = .expense { didSet { if type == .income { selectedCategoryID = nil } } }
    var selectedCategoryID: UUID?
    var memo: String = ""
    private(set) var categories: [CategoryRef] = []

    init(repository: LedgerRepository) {
        self.repository = repository
        categories = (try? repository.allCategories(includeArchived: false)) ?? []
    }

    var amountDecimal: Decimal { Decimal(string: amountDigits) ?? 0 }

    var canSave: Bool {
        amountDecimal > 0 && (type == .income || selectedCategoryID != nil)
    }

    func tapKey(_ key: String) {
        if amountDigits.isEmpty && (key == "0" || key == "00" || key == "000") { return }
        guard amountDigits.count + key.count <= 10 else { return }
        amountDigits += key
    }

    func backspace() {
        guard !amountDigits.isEmpty else { return }
        amountDigits.removeLast()
    }

    func save(date: Date) throws {
        guard canSave else { return }
        try repository.addTransaction(
            amount: amountDecimal,
            type: type,
            categoryID: type == .income ? nil : selectedCategoryID,
            memo: memo.isEmpty ? nil : memo,
            date: date
        )
    }
}
