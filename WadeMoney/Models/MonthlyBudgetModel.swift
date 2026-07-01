import Foundation
import SwiftData

@Model
final class MonthlyBudgetModel {
    var id: UUID = UUID()
    var effectiveYear: Int = 0
    var effectiveMonth: Int = 1   // 1...12, 예산월의 시작 달(=예산월 시작일의 달)
    var amount: Decimal = 0

    init(id: UUID = UUID(), effectiveYear: Int, effectiveMonth: Int, amount: Decimal) {
        self.id = id
        self.effectiveYear = effectiveYear
        self.effectiveMonth = effectiveMonth
        self.amount = amount
    }
}
