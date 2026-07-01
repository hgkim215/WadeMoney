import Foundation
import Testing
@testable import WadeMoneyCore

struct PaceCalculatorTests {
    let calc = PeriodCalculator(calendar: TS.utc, monthStartDay: 1)
    var pace: PaceCalculator { PaceCalculator(calc: calc) }
    let food = UUID()

    @Test func comparesCurrentToPriorSamePoint() {
        // 6월: 1~15일 누적 10만, 7월: 1~15일 누적 12만
        let txns = [
            TransactionRecord(amount: 100_000, type: .expense, categoryID: food, date: TS.date(2026, 6, 5)),
            TransactionRecord(amount: 999_999, type: .expense, categoryID: food, date: TS.date(2026, 6, 20)), // D 이후 → 제외
            TransactionRecord(amount: 120_000, type: .expense, categoryID: food, date: TS.date(2026, 7, 10)),
        ]
        let r = pace.pace(kind: .month, containing: TS.date(2026, 7, 1), asOf: TS.date(2026, 7, 15, 12), txns: txns)
        #expect(r.currentCumulative == 120_000)
        #expect(r.priorCumulative == 100_000)
        #expect(r.deltaRatio == Decimal(20_000) / Decimal(100_000))   // +0.2
        #expect(r.isComparable)
    }

    @Test func notComparableWhenPriorIsZero() {
        // 첫 기간(이전 달 데이터 없음)
        let txns = [
            TransactionRecord(amount: 50_000, type: .expense, categoryID: food, date: TS.date(2026, 7, 3)),
        ]
        let r = pace.pace(kind: .month, containing: TS.date(2026, 7, 1), asOf: TS.date(2026, 7, 15), txns: txns)
        #expect(r.priorCumulative == 0)
        #expect(r.deltaRatio == nil)
        #expect(!r.isComparable)
    }

    @Test func priorIsCappedToShorterPriorPeriodLength() {
        // 완료된 3월(31일) vs 2월(28일). D는 3월 전체(31)지만 이전 구간은 28로 캡.
        let txns = [
            TransactionRecord(amount: 28_000, type: .expense, categoryID: food, date: TS.date(2026, 2, 27)),
            // 2월엔 29일이 없음. 3월 29~31일 지출은 캡 로직과 무관하게 current에 포함.
            TransactionRecord(amount: 31_000, type: .expense, categoryID: food, date: TS.date(2026, 3, 30)),
        ]
        // asOf가 구간 종료 이후 → D = 31(전체)
        let r = pace.pace(kind: .month, containing: TS.date(2026, 3, 1), asOf: TS.date(2026, 5, 1), txns: txns)
        #expect(r.currentCumulative == 31_000)
        #expect(r.priorCumulative == 28_000)   // 2월 전체
    }
}
