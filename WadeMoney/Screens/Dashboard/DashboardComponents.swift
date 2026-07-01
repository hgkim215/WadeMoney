import SwiftUI
import WadeMoneyCore

private func card<Content: View>(_ scheme: ColorScheme, @ViewBuilder _ content: () -> Content) -> some View {
    let sh = WadeShadow.card(scheme)
    return content()
        .padding(WadeSpacing.cardPadding)
        .background(WadeColors.card(scheme))
        .clipShape(RoundedRectangle(cornerRadius: WadeRadius.card, style: .continuous))
        .shadow(color: sh.color, radius: sh.radius, y: sh.y)
}

struct PeriodSegment: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var kind: PeriodKind
    private let items: [(PeriodKind, String)] = [(.day, "일"), (.month, "월"), (.year, "연")]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.0) { item in
                Button { kind = item.0 } label: {
                    Text(item.1)
                        .font(WadeFont.pretendard(14, weight: .bold))
                        .foregroundStyle(kind == item.0 ? WadeColors.primary(scheme) : WadeColors.ink2(scheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(kind == item.0 ? WadeColors.card(scheme) : .clear,
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(WadeColors.card2(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.segment, style: .continuous))
    }
}

struct HeroBudgetCard: View {
    @Environment(\.colorScheme) private var scheme
    let display: DashboardViewModel.DashboardDisplay

    var body: some View {
        card(scheme) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .trim(from: 0, to: min(1, display.consumedFraction ?? 0))
                            .stroke(WadeColors.primary(scheme), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .background(Circle().stroke(WadeColors.track(scheme), lineWidth: 12))
                            .frame(width: 92, height: 92)
                        VStack(spacing: 1) {
                            Text(display.consumedPercentText ?? "—")
                                .font(WadeFont.pretendard(23, weight: .heavy))
                                .foregroundStyle(WadeColors.primary(scheme))
                            Text("소진").font(WadeFont.pretendard(10.5, weight: .semibold))
                                .foregroundStyle(WadeColors.ink3(scheme))
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(display.scopeText).font(WadeFont.pretendard(12.5, weight: .semibold))
                            .foregroundStyle(WadeColors.ink3(scheme))
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("₩").font(WadeFont.pretendard(13, weight: .bold)).foregroundStyle(WadeColors.ink2(scheme))
                            Text(display.totalText).font(WadeFont.pretendard(30, weight: .heavy))
                                .foregroundStyle(WadeColors.ink(scheme))
                        }
                        if let pace = display.pace { PaceBadgeView(pace: pace) }
                        if let dayB = display.dayBudget {
                            Text("일예산 \(dayB.dayBudgetText)원 중 \(dayB.remainText)원 남음")
                                .font(WadeFont.pretendard(11)).foregroundStyle(WadeColors.ink3(scheme))
                        }
                    }
                    Spacer(minLength: 0)
                }
                if let remain = display.remainText, let budget = display.budgetText {
                    ProgressView(value: min(1, display.consumedFraction ?? 0))
                        .tint(WadeColors.primary(scheme))
                    HStack {
                        Text("예산 \(budget)원").font(WadeFont.pretendard(12)).foregroundStyle(WadeColors.ink3(scheme))
                        Spacer()
                        Text("\(remain)원 남음").font(WadeFont.pretendard(12, weight: .bold)).foregroundStyle(WadeColors.ink2(scheme))
                    }
                }
            }
        }
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

struct DonutCard: View {
    @Environment(\.colorScheme) private var scheme
    let total: String
    let legend: [DashboardViewModel.DonutLegendItem]
    var body: some View {
        card(scheme) {
            VStack(alignment: .leading, spacing: 16) {
                Text("카테고리 비중").font(WadeFont.pretendard(15, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                HStack(spacing: 20) {
                    DonutRing(legend: legend, centerTotal: total)
                        .frame(width: 128, height: 128)
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(legend) { item in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3).fill(Color(hex: item.colorHex)).frame(width: 10, height: 10)
                                Text(item.name).font(WadeFont.pretendard(13, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
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

struct DonutRing: View {
    let legend: [DashboardViewModel.DonutLegendItem]
    let centerTotal: String
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ZStack {
            let fracs = legend.map { Double($0.percentText.dropLast()) ?? 0 }
            let total = max(fracs.reduce(0,+), 1)
            var start = 0.0
            ForEach(Array(legend.enumerated()), id: \.offset) { idx, item in
                let sweep = (Double(item.percentText.dropLast()) ?? 0) / total
                Circle()
                    .trim(from: start, to: start + sweep)
                    .stroke(Color(hex: item.colorHex), lineWidth: 22)
                    .rotationEffect(.degrees(-90))
                let _ = (start += sweep)
            }
            VStack(spacing: 1) {
                Text("총지출").font(WadeFont.pretendard(10.5, weight: .semibold)).foregroundStyle(WadeColors.ink3(scheme))
                Text(centerTotal).font(WadeFont.pretendard(16, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
            }
        }
    }
}

struct TrendCard: View {
    @Environment(\.colorScheme) private var scheme
    let bars: [DashboardViewModel.TrendBar]
    var body: some View {
        card(scheme) {
            VStack(alignment: .leading, spacing: 18) {
                Text("지출 추세").font(WadeFont.pretendard(15, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(bars) { bar in
                        VStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(bar.isCurrent ? WadeColors.primary(scheme) : WadeColors.barmuted(scheme))
                                .frame(maxWidth: 20)
                                .frame(height: max(6, bar.heightFraction * 100))
                            Text(bar.label).font(WadeFont.pretendard(9.5, weight: bar.isCurrent ? .heavy : .semibold))
                                .foregroundStyle(bar.isCurrent ? WadeColors.ink(scheme) : WadeColors.ink3(scheme))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 112, alignment: .bottom)
            }
        }
    }
}
