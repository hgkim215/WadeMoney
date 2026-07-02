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
    private let editingID: UUID?
    var isEditing: Bool { editingID != nil }

    init(repository: LedgerRepository, editing: TransactionRecord? = nil) {
        self.repository = repository
        self.categories = (try? repository.allCategories(includeArchived: false)) ?? []
        if let editing {
            self.editingID = editing.id
            self.amountDigits = "\(NSDecimalNumber(decimal: editing.amount).intValue)"
            self.type = editing.type == .income ? .income : .expense
            self.selectedCategoryID = editing.categoryID
            self.memo = editing.memo ?? ""
        } else {
            self.editingID = nil
        }
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
        let catID = type == .income ? nil : selectedCategoryID
        if let editingID {
            try repository.updateTransaction(id: editingID, amount: amountDecimal, type: type,
                                             categoryID: catID, memo: memo.isEmpty ? nil : memo, date: date)
        } else {
            try repository.addTransaction(amount: amountDecimal, type: type,
                                          categoryID: catID, memo: memo.isEmpty ? nil : memo, date: date)
        }
    }

    func delete() throws {
        guard let editingID else { return }
        try repository.deleteTransaction(id: editingID)
    }
}
