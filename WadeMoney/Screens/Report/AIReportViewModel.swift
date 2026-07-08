import Foundation
import Observation
import WadeMoneyCore

@MainActor
@Observable
final class AIReportViewModel {
    struct CategoryChange: Equatable, Identifiable {
        let id: UUID
        let name: String
        let iconName: String
        let colorHex: String
        let percentText: String
        let increased: Bool
    }
    struct InsightCardItem: Equatable, Identifiable {
        let id: String
        let iconName: String
        let text: String
    }
    struct Display: Equatable {
        let monthLabel: String
        let monthShortLabel: String
        let daysElapsedText: String
        let totalText: String
        let tag: String
        let isGood: Bool
        var summarySentence: String?
        let projectedText: String?
        let overBudgetText: String?
        let changes: [CategoryChange]
        let insightCards: [InsightCardItem]
        let projectionCaption: String?
        var tipSentence: String?
    }

    private let repository: LedgerRepository
    private let now: Date
    private let calendar: Calendar
    private let narrator: ReportNarrating
    private let aiAvailability: AIAvailabilityChecking
    private let cache: ReportNarrationCache

    private(set) var display: Display?
    private(set) var isLoading = false
    private(set) var isNarrating = false

    init(
        repository: LedgerRepository, now: Date, calendar: Calendar,
        narrator: ReportNarrating = FoundationModelsReportNarrator(),
        aiAvailability: AIAvailabilityChecking = SystemLanguageModelAvailability(),
        cache: ReportNarrationCache = ReportNarrationCache()
    ) {
        self.repository = repository
        self.now = now
        self.calendar = calendar
        self.narrator = narrator
        self.aiAvailability = aiAvailability
        self.cache = cache
        // 화면 진입 즉시 모델 로드를 시작해 데이터 준비·화면 렌더와 겹친다.
        if aiAvailability.isAvailable {
            narrator.prewarm()
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard
            let summary = try? repository.dashboardSummary(kind: .month, offset: 0, now: now, calendar: calendar),
            let categories = try? repository.allCategories(includeArchived: true),
            let monthStartDay = try? repository.settingsMonthStartDay()
        else {
            display = nil
            return
        }

        let calc = PeriodCalculator(calendar: calendar, monthStartDay: monthStartDay)
        // 페이스 비교에는 이번 달·지난달 거래만 필요 — 전체 이력을 로드하지 않는다.
        guard let txns = try? repository.transactions(
            from: calc.previous(summary.period).start, to: summary.period.end
        ) else {
            display = nil
            return
        }
        let elapsed = calc.daysElapsed(in: summary.period, asOf: now)
        let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        let categoryPace = PaceCalculator(calc: calc).categoryPace(kind: .month, containing: now, asOf: now, txns: txns)
        let changes: [CategoryChange] = categoryPace.compactMap { item in
            guard let cid = item.categoryID, let ratio = item.deltaRatio, let cat = byID[cid] else { return nil }
            let pct = Int((abs(ratio) * 100).doubleValue.rounded())
            return CategoryChange(id: cid, name: cat.name, iconName: cat.iconName, colorHex: cat.colorHex,
                                   percentText: "\(pct)%", increased: ratio > 0)
        }

        let increased = (summary.pace?.deltaRatio).map { $0 > 0 } ?? false
        let isGood = !increased
        let overBudget: Decimal? = {
            guard let budget = summary.budget, let projected = summary.projected, projected > budget else { return nil }
            return projected - budget
        }()

        // changes는 지출액 순 정렬 — "가장 많이 늘어난/줄어든"은 증감률 기준으로 따로 고른다.
        let ratioByID = Dictionary(uniqueKeysWithValues: categoryPace.compactMap { item in
            item.categoryID.flatMap { id in item.deltaRatio.map { (id, $0) } }
        })
        let topIncrease = changes
            .filter { $0.increased }
            .max { (ratioByID[$0.id] ?? 0) < (ratioByID[$1.id] ?? 0) }
        let topDecrease = changes
            .filter { !$0.increased && (ratioByID[$0.id] ?? 0) < 0 }
            .min { (ratioByID[$0.id] ?? 0) < (ratioByID[$1.id] ?? 0) }
        let monthLabel = PeriodLabel.text(kind: .month, period: summary.period, now: now, calendar: calendar)
        let monthComponent = calendar.component(.month, from: summary.period.start)

        // 인사이트는 이미 페치한 거래 배열을 재사용해 결정적으로 계산한다 — 추가 DB 조회 없음.
        let insights = InsightEngine(calc: calc).insights(
            txns: txns, period: summary.period, asOf: now, budget: summary.budget)
        let insightCards = insights.map { insightCard($0, byID: byID) }
        let dayCount = calc.dayCount(of: summary.period)
        let projectionCaption: String? =
            (summary.projected != nil && dayCount > 0 && Double(elapsed) / Double(dayCount) < 0.25)
            ? "아직 초반이라 예상치가 달라질 수 있어요" : nil

        // 0%·비교 불가 페이스는 문장 재료에서 제외한다.
        let paceDelta: (percentText: String, increased: Bool)? = summary.pace?.deltaRatio.flatMap { ratio in
            guard ratio != 0 else { return nil }
            return ("\(Int((abs(ratio) * 100).doubleValue.rounded()))%", ratio > 0)
        }
        let input = ReportInput(
            monthLabel: monthLabel,
            daysElapsedText: "\(elapsed)일",
            totalExpenseText: Won.string(summary.totalExpense),
            budgetStatusText: overBudget != nil ? "예산 초과 예상 +\(Won.string(overBudget!))원" : "예산 내 예상",
            paceDelta: paceDelta,
            projectedTotalText: summary.projected.map { Won.string($0) } ?? "-",
            topIncrease: topIncrease.map { (name: $0.name, percentText: $0.percentText) },
            topDecrease: topDecrease.map { (name: $0.name, percentText: $0.percentText) },
            insightFacts: insightCards.map(\.text)
        )

        // 1단계: 결정적 수치를 즉시 표시한다 — AI 문장을 기다리며 화면을 비워두지 않는다.
        display = Display(
            monthLabel: monthLabel,
            monthShortLabel: "\(monthComponent)월",
            daysElapsedText: input.daysElapsedText,
            totalText: input.totalExpenseText,
            tag: isGood ? "양호" : "주의",
            isGood: isGood,
            summarySentence: nil,
            projectedText: summary.projected.map { Won.string($0) },
            overBudgetText: overBudget.map { "+\(Won.string($0))원" },
            changes: changes,
            insightCards: insightCards,
            projectionCaption: projectionCaption,
            tipSentence: nil
        )
        isLoading = false

        // 2단계: AI 문장 — 같은 입력이면 캐시로 즉시, 아니면 생성 후 캐시.
        let aiOn = aiAvailability.isAvailable && (try? repository.aiEnabled()) == true
        guard aiOn else { return }

        let key = Self.narrationCacheKey(for: input)
        if let cached = cache.narration(for: key) {
            apply(cached)
            return
        }

        isNarrating = true
        defer { isNarrating = false }
        guard let narration = try? await narrator.narrate(input) else { return }
        cache.store(narration, for: key)
        apply(narration)
    }

    /// 인사이트 원시 값 → 카드 문장. 수치는 전부 여기서 포매팅되고 AI는 이 문장을 인용만 한다.
    private func insightCard(_ insight: Insight, byID: [UUID: CategoryRef]) -> InsightCardItem {
        func pct(_ ratio: Decimal) -> Int { Int((abs(ratio) * 100).doubleValue.rounded()) }
        switch insight {
        case .budgetRunway(let exhaustDate):
            let c = calendar.dateComponents([.month, .day], from: exhaustDate)
            return .init(id: "runway", iconName: "hourglass_bottom",
                         text: "이 속도면 \(c.month ?? 0)월 \(c.day ?? 0)일쯤 예산이 소진돼요")
        case .largestExpense(let amount, let categoryID, let memo, let share):
            let name = memo?.isEmpty == false ? memo! : (categoryID.flatMap { byID[$0]?.name } ?? "기타")
            return .init(id: "largest", iconName: "payments",
                         text: "가장 큰 지출은 \(name) \(Won.string(amount))원 — 이번 달 지출의 \(pct(share))%예요")
        case .dailyAveragePace(let avg, let delta):
            let up = delta > 0
            return .init(id: "pace", iconName: up ? "trending_up" : "trending_down",
                         text: "하루 평균 \(Won.string(avg))원 쓰고 있어요 — 지난달 같은 시점보다 \(pct(delta))% \(up ? "높아요" : "낮아요")")
        case .frequency(let categoryID, let count, let total, let avgPerVisit):
            let name = categoryID.flatMap { byID[$0]?.name } ?? "기타"
            return .init(id: "frequency", iconName: "repeat",
                         text: "\(name)에 \(count)번 · 총 \(Won.string(total))원 · 회당 평균 \(Won.string(avgPerVisit))원")
        case .weekendConcentration(let fraction):
            return .init(id: "weekend", iconName: "weekend",
                         text: "지출의 \(pct(fraction))%가 주말에 몰려 있어요")
        case .noSpendDays(let count):
            return .init(id: "nospend", iconName: "event_available",
                         text: "이번 달 무지출일이 \(count)일 있었어요")
        }
    }

    private func apply(_ narration: ReportNarration) {
        display?.summarySentence = narration.summarySentence
        display?.tipSentence = narration.tipSentence
    }

    /// 내레이션에 영향을 주는 모든 입력 필드로 캐시 키를 만든다 — 데이터가 바뀌면 키도 바뀐다.
    private static func narrationCacheKey(for input: ReportInput) -> String {
        [
            input.monthLabel, input.daysElapsedText, input.totalExpenseText,
            input.budgetStatusText,
            input.paceDelta.map { "\($0.percentText)|\($0.increased)" } ?? "-",
            input.projectedTotalText,
            input.topIncrease.map { "\($0.name)|\($0.percentText)" } ?? "-",
            input.topDecrease.map { "\($0.name)|\($0.percentText)" } ?? "-",
            input.insightFacts.joined(separator: "\u{1E}"),
        ].joined(separator: "\u{1F}")
    }
}
