import Foundation

public enum Projection {
    /// 현재 누적을 전체 기간으로 선형 환산. 경과일이 0이면 0.
    public static func projectedTotal(cumulative: Decimal, daysElapsed: Int, daysInPeriod: Int) -> Decimal {
        guard daysElapsed > 0 else { return 0 }
        return cumulative / Decimal(daysElapsed) * Decimal(daysInPeriod)
    }
}
