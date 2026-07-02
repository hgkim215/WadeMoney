import Foundation
import Observation
import WadeMoneyCore

@MainActor
@Observable
final class QuickAddViewModel {
    private let repository: LedgerRepository
    private let aiAvailability: AIAvailabilityChecking
    private let memoPolisher: MemoPolishing

    var amountDigits: String = ""
    var type: TransactionKind = .expense { didSet { if type == .income { selectedCategoryID = nil } } }
    var selectedCategoryID: UUID?
    var memo: String = ""
    private(set) var categories: [CategoryRef] = []
    private let editingID: UUID?
    var isEditing: Bool { editingID != nil }
    private(set) var isPolishing = false
    private(set) var hasPolished = false
    private(set) var polishNote: String?

    var showsPolishButton: Bool {
        !memo.trimmingCharacters(in: .whitespaces).isEmpty
            && aiAvailability.isAvailable
            && (try? repository.aiEnabled()) == true
    }

    init(
        repository: LedgerRepository, editing: TransactionRecord? = nil,
        preselectedCategoryID: UUID? = nil,
        aiAvailability: AIAvailabilityChecking = SystemLanguageModelAvailability(),
        memoPolisher: MemoPolishing = FoundationModelsMemoPolisher()
    ) {
        self.repository = repository
        self.aiAvailability = aiAvailability
        self.memoPolisher = memoPolisher
        self.categories = (try? repository.allCategories(includeArchived: false)) ?? []
        if let editing {
            self.editingID = editing.id
            self.amountDigits = "\(NSDecimalNumber(decimal: editing.amount).intValue)"
            self.type = editing.type == .income ? .income : .expense
            self.selectedCategoryID = editing.categoryID
            self.memo = editing.memo ?? ""
        } else {
            self.editingID = nil
            self.selectedCategoryID = preselectedCategoryID
        }
    }

    func polishMemo() async {
        guard !isPolishing, !memo.isEmpty else { return }
        isPolishing = true
        defer { isPolishing = false }
        do {
            let names = categories.map(\.name)
            let result = try await memoPolisher.polish(memo: memo, categoryNames: names)
            memo = result.polishedMemo
            hasPolished = true
            if type == .expense, selectedCategoryID == nil,
               let name = result.suggestedCategoryName,
               let match = categories.first(where: { $0.name == name }) {
                selectedCategoryID = match.id
                polishNote = "메모를 다듬고 \(match.name) 카테고리를 추천했어요"
            } else {
                polishNote = nil
            }
        } catch {
            // 조용히 실패 — 메모는 원본 유지, 버튼은 원상태로.
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
