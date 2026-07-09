import SwiftUI
import SwiftData
import WadeMoneyCore

struct AIReportScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AIReportViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WadeSpacing.cardGap) {
                backRow
                header
                if let vm = viewModel, let d = vm.display {
                    summaryCard(d, isNarrating: vm.isNarrating)
                    projectionCard(d)
                    if !d.insightCards.isEmpty { insightsCard(d) }
                    if !d.changes.isEmpty { changesCard(d) }
                    if let tip = d.tipSentence {
                        tipCard(tip)
                    } else if vm.isNarrating {
                        tipCard("절약 팁을 준비하고 있어요…", isPlaceholder: true)
                    }
                    footerNote
                }
            }
            .padding(.horizontal, WadeSpacing.screenH)
            .padding(.top, WadeSpacing.contentTop)
            .padding(.bottom, WadeSpacing.contentBottom)
            .animation(.easeInOut(duration: 0.25), value: viewModel?.display?.tipSentence)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WadeColors.bg(scheme))
        .navigationBarBackButtonHidden(true)
        .enableSwipeBack { dismiss() }
        .task {
            if viewModel == nil {
                let vm = AIReportViewModel(repository: LedgerRepository(context: modelContext), now: Date(), calendar: .current)
                viewModel = vm
                await vm.load()
            }
        }
    }

    private var backRow: some View {
        Button { dismiss() } label: {
            HStack(spacing: 3) { Icon("chevron_left", size: 18); Text("대시보드").font(WadeFont.pretendard(14, weight: .semibold)) }
                .foregroundStyle(WadeColors.ink2(scheme))
        }.buttonStyle(.plain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Icon("auto_awesome", size: 20).foregroundStyle(WadeColors.primary(scheme))
                Text("\(viewModel?.display?.monthShortLabel ?? "") 소비 리포트")
                    .font(WadeFont.pretendard(22, weight: .heavy)).foregroundStyle(WadeColors.ink(scheme))
            }
            if let d = viewModel?.display {
                Text("\(d.monthLabel) · \(d.daysElapsedText) 경과")
                    .font(WadeFont.pretendard(12.5)).foregroundStyle(WadeColors.ink3(scheme))
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let sh = WadeShadow.card(scheme)
        // frame이 background보다 먼저 와야 카드 배경이 항상 화면 폭을 채운다 —
        // 뒤에 두면 레이아웃 박스만 넓어지고 배경은 콘텐츠 폭에 머문다.
        return content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(WadeSpacing.cardPadding)
            .background(WadeColors.card(scheme))
            .clipShape(RoundedRectangle(cornerRadius: WadeRadius.card, style: .continuous))
            .shadow(color: sh.color, radius: sh.radius, y: sh.y)
    }

    private func summaryCard(_ d: AIReportViewModel.Display, isNarrating: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("이번 달 요약").font(WadeFont.pretendard(13, weight: .bold)).foregroundStyle(WadeColors.ink(scheme))
                if isNarrating {
                    ProgressView().controlSize(.mini)
                }
                Spacer()
                Text(d.tag)
                    .font(WadeFont.pretendard(11, weight: .bold))
                    .foregroundStyle(d.isGood ? WadeColors.good(scheme) : WadeColors.bad(scheme))
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(d.isGood ? WadeColors.goodsoft(scheme) : WadeColors.badsoft(scheme), in: Capsule())
            }
            SentenceHighlighter.styledText(
                d.summarySentence ?? "이번 달 총지출은 \(d.totalText)원이에요.",
                font: WadeFont.pretendard(14.5),
                scheme: scheme
            )
        }
        .padding(WadeSpacing.cardPadding)
        .background(
            LinearGradient(colors: [WadeColors.aitint1(scheme), WadeColors.aitint2(scheme)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: WadeRadius.card, style: .continuous)
        )
    }

    private func projectionCard(_ d: AIReportViewModel.Display) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("이번 달 예상 지출").font(WadeFont.pretendard(13, weight: .bold)).foregroundStyle(WadeColors.ink3(scheme))
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("₩").font(WadeFont.pretendard(14, weight: .bold))
                    // 금액은 절대 말줄임하지 않는다 — 폭이 모자라면 글자를 줄여 전 자리수를 보여준다.
                    Text(d.projectedText ?? "-").font(WadeFont.pretendard(26, weight: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .foregroundStyle(WadeColors.ink(scheme))
                if let over = d.overBudgetText {
                    Text("예산 초과 예상 \(over)")
                        .font(WadeFont.pretendard(12, weight: .bold))
                        .foregroundStyle(WadeColors.bad(scheme))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(WadeColors.badsoft(scheme), in: Capsule())
                }
                if let caption = d.projectionCaption {
                    Text(caption).font(WadeFont.pretendard(11.5)).foregroundStyle(WadeColors.ink3(scheme))
                }
            }
        }
    }

    private func insightsCard(_ d: AIReportViewModel.Display) -> some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text("이번 달 발견").font(WadeFont.pretendard(13, weight: .bold)).foregroundStyle(WadeColors.ink(scheme))
                ForEach(d.insightCards) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Icon(item.iconName, size: 18).foregroundStyle(WadeColors.primary(scheme))
                            .frame(width: 32, height: 32)
                            .background(WadeColors.primarysoft(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.smallTile))
                        SentenceHighlighter.styledText(item.text, font: WadeFont.pretendard(13.5), scheme: scheme)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func changesCard(_ d: AIReportViewModel.Display) -> some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text("지난달 대비 변화").font(WadeFont.pretendard(13, weight: .bold)).foregroundStyle(WadeColors.ink(scheme))
                ForEach(d.changes) { change in
                    HStack(spacing: 10) {
                        Icon(change.iconName, size: 18).foregroundStyle(Color(hex: change.colorHex))
                            .frame(width: 32, height: 32)
                            .background(Color(hex: change.colorHex).opacity(0.13), in: RoundedRectangle(cornerRadius: WadeRadius.smallTile))
                        Text(change.name).font(WadeFont.pretendard(13.5, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
                        Spacer()
                        HStack(spacing: 2) {
                            Icon(change.increased ? "arrow_drop_up" : "arrow_drop_down", size: 16)
                            Text(change.percentText).font(WadeFont.pretendard(12.5, weight: .bold))
                        }
                        .foregroundStyle(change.increased ? WadeColors.bad(scheme) : WadeColors.good(scheme))
                    }
                }
            }
        }
    }

    private func tipCard(_ tip: String, isPlaceholder: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Icon("lightbulb", size: 19).foregroundStyle(WadeColors.primary(scheme))
            SentenceHighlighter.styledText(tip, font: WadeFont.pretendard(13.5), scheme: scheme)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WadeSpacing.cardPadding)
        .background(WadeColors.primarysoft(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.card, style: .continuous))
        .redacted(reason: isPlaceholder ? .placeholder : [])
    }

    private var footerNote: some View {
        HStack(spacing: 5) {
            Icon("lock", size: 13)
            Text("온디바이스에서 생성됨 · 데이터는 기기를 벗어나지 않아요")
                .font(WadeFont.pretendard(11))
        }
        .foregroundStyle(WadeColors.ink3(scheme))
        .frame(maxWidth: .infinity)
    }
}
