import Foundation
import WadeMoneyCore

/// 위젯이 표시할 데이터를 계산하는 순수 로직. WidgetKit을 import하지 않아
/// 앱 타깃(WadeMoneyTests)에서 TDD로 검증할 수 있고, 위젯 확장 타깃에서도
/// 동일 파일을 공유해 TimelineProvider가 그대로 사용한다.
@MainActor
enum WidgetDataBuilder {
    struct SummaryData {
        let todayExpenseText: String
        let monthRemainingText: String?
        let consumedFraction: Double?
    }

    static func summary(repository: LedgerRepository, now: Date, calendar: Calendar) -> SummaryData {
        guard
            let day = try? repository.dashboardSummary(kind: .day, offset: 0, now: now, calendar: calendar),
            let month = try? repository.dashboardSummary(kind: .month, offset: 0, now: now, calendar: calendar)
        else {
            return SummaryData(todayExpenseText: "0", monthRemainingText: nil, consumedFraction: nil)
        }
        return SummaryData(
            todayExpenseText: Won.string(day.totalExpense),
            monthRemainingText: month.remaining.map { "\(Won.string($0))원 남음" },
            consumedFraction: month.consumedFraction
        )
    }
}

extension WidgetDataBuilder {
    struct ChipData: Identifiable {
        let id: UUID
        let name: String
        let iconName: String
        let colorHex: String
    }

    /// sortOrder 오름차순 활성 카테고리 상위 3개("직접" 칩은 위젯 뷰에서 별도 추가).
    static func quickRecordChips(repository: LedgerRepository) -> [ChipData] {
        let categories = (try? repository.allCategories(includeArchived: false)) ?? []
        return categories.prefix(3).map {
            ChipData(id: $0.id, name: $0.name, iconName: $0.iconName, colorHex: $0.colorHex)
        }
    }
}
