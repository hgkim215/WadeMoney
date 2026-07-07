import Foundation
import Testing
import WadeMoneyCore
@testable import WadeMoney

@MainActor
struct ModelMappingTests {
    @Test func transactionModelMapsToRecord() {
        let cat = CategoryModel(name: "식비", iconName: "restaurant", colorHex: "#E28A4E", sortOrder: 0)
        let tx = TransactionModel(amount: 9000, type: .expense, category: cat,
                                  memo: "점심", date: Date(timeIntervalSince1970: 500),
                                  createdAt: Date(timeIntervalSince1970: 400))
        let rec = tx.toRecord()
        #expect(rec.amount == 9000)
        #expect(rec.type == .expense)
        #expect(rec.categoryID == cat.id)
        #expect(rec.memo == "점심")
        #expect(rec.date == Date(timeIntervalSince1970: 500))
        #expect(rec.isExcludedFromBudget == false)
    }

    @Test func transactionModelMapsBudgetExclusionFlag() {
        let cat = CategoryModel(name: "가족", iconName: "family_restroom", colorHex: "#D3A850", sortOrder: 0)
        let tx = TransactionModel(amount: 500_000, type: .expense, category: cat,
                                  memo: "첫 월급", date: Date(timeIntervalSince1970: 500),
                                  isExcludedFromBudget: true)

        #expect(tx.toRecord().isExcludedFromBudget == true)
    }

    @Test func incomeMapsWithNilCategory() {
        let tx = TransactionModel(amount: 45000, type: .income, category: nil,
                                  memo: "중고거래", date: Date(timeIntervalSince1970: 0))
        let rec = tx.toRecord()
        #expect(rec.type == .income)
        #expect(rec.categoryID == nil)
    }

    @Test func categoryModelMapsToRef() {
        let cat = CategoryModel(name: "카페", iconName: "local_cafe", colorHex: "#C4924E",
                                sortOrder: 2, isArchived: true)
        let ref = cat.toRef()
        #expect(ref.id == cat.id)
        #expect(ref.name == "카페")
        #expect(ref.iconName == "local_cafe")
        #expect(ref.colorHex == "#C4924E")
        #expect(ref.sortOrder == 2)
        #expect(ref.isArchived == true)
    }

    @Test func budgetModelMapsToSnapshot() {
        let b = MonthlyBudgetModel(effectiveYear: 2026, effectiveMonth: 7, amount: 1_300_000)
        let snap = b.toSnapshot()
        #expect(snap.effectiveMonth == YearMonth(year: 2026, month: 7))
        #expect(snap.amount == 1_300_000)
    }

    @Test func settingsModelMapsToEngineSettings() {
        let s = AppSettingsModel(monthStartDay: 25, aiEnabled: false)
        let es = s.toEngineSettings()
        #expect(es.monthStartDay == 25)
        #expect(es.aiEnabled == false)
    }
}
