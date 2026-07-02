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
    var memo: String = "" {
        didSet {
            // 다듬은 뒤 사용자가 메모를 고치면 다시 다듬을 수 있게 되돌린다.
            if hasPolished && memo != polishedMemoSnapshot { hasPolished = false }
        }
    }
    private var polishedMemoSnapshot: String?
    private(set) var categories: [CategoryRef] = []
    private let editingID: UUID?
    var date: Date
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
            self.date = editing.date
            self.amountDigits = "\(NSDecimalNumber(decimal: editing.amount).intValue)"
            self.type = editing.type == .income ? .income : .expense
            self.selectedCategoryID = editing.categoryID
            self.memo = editing.memo ?? ""
        } else {
            self.editingID = nil
            self.date = Date()
            // 딥링크로 받은 카테고리가 보관(아카이브)됐다면 무시한다 — 화면에 없는 카테고리가 몰래 저장되는 것 방지.
            self.selectedCategoryID = categories.contains { $0.id == preselectedCategoryID } ? preselectedCategoryID : nil
        }
    }

    func polishMemo() async {
        guard !isPolishing, !memo.isEmpty else { return }
        isPolishing = true
        defer { isPolishing = false }
        do {
            let names = categories.map(\.name)
            let original = memo
            let result = try await memoPolisher.polish(memo: original, categoryNames: names)
            // 생성 중 사용자가 메모를 수정했다면 결과로 덮어쓰지 않는다.
            guard memo == original else { return }
            // 모델이 빈 문자열을 돌려주면 원본을 지키고 재시도 가능 상태로 남긴다.
            let polished = result.polishedMemo.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !polished.isEmpty else { return }
            polishedMemoSnapshot = polished
            memo = polished
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

    func save() throws {
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
}
