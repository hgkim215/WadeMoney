import Foundation

public enum Projection {
    /// 현재 누적을 전체 기간으로 선형 환산. 경과일이 0이면 0.
    public static func projectedTotal(cumulative: Decimal, daysElapsed: Int, daysInPeriod: Int) -> Decimal {
        guard daysElapsed > 0 else { return 0 }
        return cumulative * Decimal(daysInPeriod) / Decimal(daysElapsed)
    }

    /// 누적 합의 30% 이상을 단독으로 차지하는 지출(일회성)과 나머지(일상)로 분리.
    /// 월초 큰 지출 하나가 선형 외삽으로 달 전체에 곱해지는 왜곡을 막는 기준.
    public static func splitOneOffs(amounts: [Decimal]) -> (oneOff: Decimal, routine: Decimal) {
        let total = amounts.reduce(Decimal(0), +)
        guard total > 0 else { return (0, 0) }
        let threshold = total * 3 / 10
        let oneOff = amounts.filter { $0 >= threshold }.reduce(Decimal(0), +)
        return (oneOff, total - oneOff)
    }

    /// 일회성 지출을 분리한 안정화 예상치: 일회성 실적 + 일상 지출의 선형 외삽.
    public static func stabilizedProjectedTotal(
        amounts: [Decimal], daysElapsed: Int, daysInPeriod: Int
    ) -> Decimal {
        guard daysElapsed > 0 else { return 0 }
        let (oneOff, routine) = splitOneOffs(amounts: amounts)
        return oneOff + routine * Decimal(daysInPeriod) / Decimal(daysElapsed)
    }
}
