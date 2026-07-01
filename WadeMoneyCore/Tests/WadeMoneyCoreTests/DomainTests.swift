import Foundation
import Testing
@testable import WadeMoneyCore

struct DomainTests {
    @Test func transactionDefaultsAreExpense() {
        let t = TransactionRecord(amount: 4800, date: Date(timeIntervalSince1970: 0))
        #expect(t.type == .expense)
        #expect(t.categoryID == nil)
        #expect(t.amount == 4800)
    }

    @Test func decimalConvertsToDouble() {
        #expect(Decimal(string: "0.25")!.doubleValue == 0.25)
        #expect(Decimal(150).doubleValue == 150.0)
    }
}
