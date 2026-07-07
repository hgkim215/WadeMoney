import SwiftUI
import WadeMoneyCore

private func card<Content: View>(_ scheme: ColorScheme, minHeight: CGFloat? = nil, @ViewBuilder _ content: () -> Content) -> some View {
    let sh = WadeShadow.card(scheme)
    return content()
        .padding(WadeSpacing.cardPadding)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .center)
        .background(WadeColors.card(scheme))
        .clipShape(RoundedRectangle(cornerRadius: WadeRadius.card, style: .continuous))
        .shadow(color: sh.color, radius: sh.radius, y: sh.y)
}

struct PeriodSegment: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var kind: PeriodKind
    private let items: [(PeriodKind, String)] = [(.day, "일"), (.month, "월"), (.year, "연")]
    private var segmentStroke: Color { WadeColors.ink3(scheme).opacity(scheme == .dark ? 0.34 : 0.18) }
    private var selectedStroke: Color { WadeColors.line(scheme).opacity(scheme == .dark ? 0.80 : 1) }
    private var selectedShadow: Color {
        scheme == .dark ? Color.black.opacity(0.18) : Color(red: 120/255, green: 90/255, blue: 60/255).opacity(0.08)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.0) { item in
                Button {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                        kind = item.0
                    }
                } label: {
                    Text(item.1)
                        .font(WadeFont.pretendard(14, weight: .bold))
                        .foregroundStyle(kind == item.0 ? WadeColors.primary(scheme) : WadeColors.ink2(scheme))
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .contentShape(RoundedRectangle(cornerRadius: WadeRadius.smallTile, style: .continuous))
                        .background {
                            RoundedRectangle(cornerRadius: WadeRadius.smallTile, style: .continuous)
                                .fill(kind == item.0 ? WadeColors.card(scheme) : .clear)
                                .shadow(color: kind == item.0 ? selectedShadow : .clear, radius: 7, y: 2)
                        }
                        .overlay {
                            if kind == item.0 {
                                RoundedRectangle(cornerRadius: WadeRadius.smallTile, style: .continuous)
                                    .stroke(selectedStroke, lineWidth: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: WadeRadius.smallTile, style: .continuous))
            }
        }
        .padding(4)
        .background(WadeColors.card2(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.segment, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WadeRadius.segment, style: .continuous)
                .stroke(segmentStroke, lineWidth: 1)
        )
    }
}

struct HeroBudgetCard: View {
    @Environment(\.colorScheme) private var scheme
    let display: DashboardViewModel.DashboardDisplay

    var body: some View {
        card(scheme, minHeight: WadeSpacing.dashboardBlockHeight) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 18) {
                    if let fraction = display.consumedFraction, let percentText = display.consumedPercentText {
                        BudgetProgressRing(fraction: fraction, percentText: percentText)
                    } else {
                        BudgetUnsetBadge()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(display.scopeText).font(WadeFont.pretendard(12.5, weight: .semibold))
                            .foregroundStyle(WadeColors.ink3(scheme))
                        if display.hasExpense {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("₩").font(WadeFont.pretendard(13, weight: .bold)).foregroundStyle(WadeColors.ink2(scheme))
                                Text(display.totalText).font(WadeFont.pretendard(30, weight: .heavy))
                                    .foregroundStyle(WadeColors.ink(scheme))
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("첫 소비를 기록해보세요")
                                    .font(WadeFont.pretendard(19, weight: .heavy))
                                    .foregroundStyle(WadeColors.ink(scheme))
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("기록이 쌓이면 지출 흐름이 보여요")
                                    .font(WadeFont.pretendard(11.5, weight: .semibold))
                                    .foregroundStyle(WadeColors.ink3(scheme))
                            }
                        }
                        if let pace = display.pace { PaceBadgeView(pace: pace) }
                        if let dayB = display.dayBudget {
                            Text("일예산 \(dayB.dayBudgetText)원 중 \(dayB.remainText)원 남음")
                                .font(WadeFont.pretendard(11)).foregroundStyle(WadeColors.ink3(scheme))
                        } else if display.budgetText == nil, display.hasExpense {
                            Text("예산 미설정")
                                .font(WadeFont.pretendard(11.5, weight: .bold))
                                .foregroundStyle(WadeColors.ink3(scheme))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(WadeColors.card2(scheme), in: Capsule())
                        }
                        if display.budgetText == nil, !display.hasExpense {
                            Text("예산 미설정")
                                .font(WadeFont.pretendard(11.5, weight: .bold))
                                .foregroundStyle(WadeColors.ink3(scheme))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(WadeColors.card2(scheme), in: Capsule())
                        }
                    }
                    Spacer(minLength: 0)
                }
                if let remain = display.remainText, let budget = display.budgetText {
                    HStack {
                        Text(display.budgetBasisText ?? "예산 \(budget)원")
                            .font(WadeFont.pretendard(12))
                            .foregroundStyle(WadeColors.ink3(scheme))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Spacer()
                        Text("\(remain)원 남음").font(WadeFont.pretendard(12, weight: .bold)).foregroundStyle(WadeColors.ink2(scheme))
                    }
                }
            }
        }
    }
}

private struct BudgetProgressRing: View {
    @Environment(\.colorScheme) private var scheme
    let fraction: Double
    let percentText: String

    private var paceColor: Color { WadeColors.budgetPace(scheme, fraction: fraction) }

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: min(1, fraction))
                .stroke(paceColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .background(Circle().stroke(WadeColors.track(scheme), lineWidth: 12))
                .frame(width: 104, height: 104)
            VStack(spacing: 1) {
                Text(percentText)
                    .font(WadeFont.pretendard(23, weight: .heavy))
                    .foregroundStyle(paceColor)
                Text("소진").font(WadeFont.pretendard(10.5, weight: .semibold))
                    .foregroundStyle(WadeColors.ink3(scheme))
            }
        }
        .frame(width: 104, height: 104)
    }
}

private struct BudgetUnsetBadge: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Circle()
                .fill(WadeColors.card2(scheme))
                .overlay(Circle().stroke(WadeColors.track(scheme), lineWidth: 1))
            VStack(spacing: 5) {
                Icon("account_balance_wallet", size: 27)
                    .foregroundStyle(WadeColors.primary(scheme))
                Text("예산 없음")
                    .font(WadeFont.pretendard(10.5, weight: .semibold))
                    .foregroundStyle(WadeColors.ink3(scheme))
            }
        }
        .frame(width: 104, height: 104)
    }
}

struct PaceBadgeView: View {
    @Environment(\.colorScheme) private var scheme
    let pace: DashboardViewModel.PaceBadge
    var body: some View {
        let up = pace.direction == .up
        let fg = up ? WadeColors.bad(scheme) : WadeColors.good(scheme)
        let bg = up ? WadeColors.badsoft(scheme) : WadeColors.goodsoft(scheme)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 3) {
                Icon(up ? "arrow_drop_up" : "arrow_drop_down", size: 17)
                Text(pace.deltaText).font(WadeFont.pretendard(12.5, weight: .bold))
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(bg, in: Capsule())
            Text(pace.note).font(WadeFont.pretendard(11)).foregroundStyle(WadeColors.ink3(scheme))
        }
    }
}

struct InsightCard: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    let isGood: Bool
    let onDetail: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Icon("auto_awesome", size: 17).foregroundStyle(WadeColors.primary(scheme))
                    Text("AI 인사이트").font(WadeFont.pretendard(13, weight: .bold)).foregroundStyle(WadeColors.ink(scheme))
                }
                Spacer()
                Text(isGood ? "양호" : "주의")
                    .font(WadeFont.pretendard(11, weight: .bold))
                    .foregroundStyle(isGood ? WadeColors.good(scheme) : WadeColors.bad(scheme))
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(isGood ? WadeColors.goodsoft(scheme) : WadeColors.badsoft(scheme), in: Capsule())
            }
            Text(text).font(WadeFont.pretendard(13.5)).foregroundStyle(WadeColors.ink2(scheme))
            Button(action: onDetail) {
                Text("자세히 보기 ›").font(WadeFont.pretendard(12.5, weight: .bold)).foregroundStyle(WadeColors.primary(scheme))
            }.buttonStyle(.plain)
        }
        .padding(WadeSpacing.cardPadding)
        .background(
            LinearGradient(colors: [WadeColors.aitint1(scheme), WadeColors.aitint2(scheme)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: WadeRadius.card, style: .continuous)
        )
    }
}

struct DonutCard: View {
    @Environment(\.colorScheme) private var scheme
    let total: String
    let hasExpense: Bool
    let legend: [DashboardViewModel.DonutLegendItem]
    private let ringSize: CGFloat = 104
    private let ringLineWidth: CGFloat = 18

    var body: some View {
        card(scheme, minHeight: WadeSpacing.dashboardBlockHeight) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("카테고리 비중").font(WadeFont.pretendard(15, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                    Spacer()
                    if !legend.isEmpty {
                        HStack(spacing: 2) {
                            Text("자세히").font(WadeFont.pretendard(12, weight: .bold))
                            Icon("chevron_right", size: 14, filled: false)
                        }
                        .foregroundStyle(WadeColors.ink3(scheme))
                    }
                }
                if legend.isEmpty {
                    emptyState
                } else {
                    HStack(spacing: 28) {
                        DonutRing(legend: legend, outerSize: ringSize, lineWidth: ringLineWidth)
                            .frame(width: ringSize, height: ringSize)
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(legend) { item in
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: item.colorHex)).frame(width: 10, height: 10)
                                    Text(item.name).font(WadeFont.pretendard(13, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(item.percentText).font(WadeFont.pretendard(13, weight: .heavy)).foregroundStyle(WadeColors.ink2(scheme))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: 28) {
            ZStack {
                Circle().fill(WadeColors.card2(scheme)).frame(width: ringSize, height: ringSize)
                VStack(spacing: 4) {
                    Icon("category", size: 25)
                        .foregroundStyle(WadeColors.primary(scheme))
                    if hasExpense {
                        Text("총지출").font(WadeFont.pretendard(10.5, weight: .semibold)).foregroundStyle(WadeColors.ink3(scheme))
                        Text(total).font(WadeFont.pretendard(16, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                    }
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(hasExpense ? "아직 지출이 없어요" : "기록 후 비중이 보여요")
                    .font(WadeFont.pretendard(14, weight: .heavy))
                    .foregroundStyle(WadeColors.ink2(scheme))
                if !hasExpense {
                    Text("첫 소비를 남기면 카테고리별로 정리돼요")
                        .font(WadeFont.pretendard(12, weight: .semibold))
                        .foregroundStyle(WadeColors.ink3(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct DonutRing: View {
    let legend: [DashboardViewModel.DonutLegendItem]
    let outerSize: CGFloat
    let lineWidth: CGFloat
    @Environment(\.colorScheme) private var scheme

    private var top: DashboardViewModel.DonutLegendItem? { legend.first }

    private var arcs: [(start: Double, end: Double, color: Color)] {
        var result: [(Double, Double, Color)] = []
        var cursor = 0.0
        let total = max(legend.reduce(0) { $0 + $1.fraction }, 0.0001)
        for item in legend {
            let sweep = item.fraction / total
            result.append((cursor, cursor + sweep, Color(hex: item.colorHex)))
            cursor += sweep
        }
        return result
    }

    var body: some View {
        let pathSize = max(1, outerSize - lineWidth)

        ZStack {
            Circle()
                .stroke(WadeColors.track(scheme), lineWidth: lineWidth)
                .frame(width: pathSize, height: pathSize)
            ForEach(Array(arcs.enumerated()), id: \.offset) { _, arc in
                Circle()
                    .trim(from: arc.start, to: arc.end)
                    .stroke(arc.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .frame(width: pathSize, height: pathSize)
            }
            if let top {
                VStack(spacing: 3) {
                    Text("최다 지출")
                        .font(WadeFont.pretendard(9.5, weight: .semibold))
                        .foregroundStyle(WadeColors.ink3(scheme))
                    Text(top.name)
                        .font(WadeFont.pretendard(14, weight: .heavy))
                        .foregroundStyle(WadeColors.ink(scheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .multilineTextAlignment(.center)
                .frame(width: max(42, outerSize - (lineWidth * 2) - 12))
            }
        }
        .frame(width: outerSize, height: outerSize)
    }
}

struct TrendCard: View {
    @Environment(\.colorScheme) private var scheme
    let bars: [DashboardViewModel.TrendBar]
    @State private var selectedID: Int?

    private var selectedBar: DashboardViewModel.TrendBar? {
        TrendCard.selectedBar(in: bars, id: selectedID)
    }

    var body: some View {
        card(scheme, minHeight: WadeSpacing.dashboardBlockHeight) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("지출 추세").font(WadeFont.pretendard(15, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                    Spacer()
                    if let selectedBar {
                        Text("\(selectedBar.label) · ₩\(selectedBar.valueText)")
                            .font(WadeFont.pretendard(13, weight: .heavy))
                            .foregroundStyle(WadeColors.primary(scheme))
                    }
                }
                if bars.contains(where: { $0.heightFraction > 0 }) {
                    HStack(alignment: .bottom, spacing: 5) {
                        ForEach(bars) { bar in
                            let isSelected = bar.id == selectedBar?.id
                            VStack(spacing: 7) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(isSelected ? WadeColors.primary(scheme) : WadeColors.barmuted(scheme))
                                    .frame(maxWidth: 20)
                                    .frame(height: max(6, bar.heightFraction * 100))
                                Text(bar.label).font(WadeFont.pretendard(9.5, weight: isSelected ? .heavy : .semibold))
                                    .foregroundStyle(isSelected ? WadeColors.ink(scheme) : WadeColors.ink3(scheme))
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedID = bar.id }
                        }
                    }
                    .frame(height: 112, alignment: .bottom)
                } else {
                    VStack(spacing: 7) {
                        Icon("bar_chart", size: 28)
                            .foregroundStyle(WadeColors.primary(scheme))
                        Text("아직 추세가 없어요")
                            .font(WadeFont.pretendard(13, weight: .semibold))
                            .foregroundStyle(WadeColors.ink3(scheme))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 112)
                    .background(WadeColors.card2(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.smallTile, style: .continuous))
                }
            }
        }
        .onChange(of: bars) { selectedID = nil }
    }

    static func selectedBar(in bars: [DashboardViewModel.TrendBar], id: Int?) -> DashboardViewModel.TrendBar? {
        if let id, let match = bars.first(where: { $0.id == id }) { return match }
        return bars.first { $0.isCurrent }
    }
}
