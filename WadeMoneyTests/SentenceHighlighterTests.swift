import Testing
@testable import WadeMoney

struct SentenceHighlighterTests {
    @Test func detectsIncreasePercentNearIncreaseKeyword() {
        let spans = SentenceHighlighter.spans(in: "카페 지출이 지난달 같은 시점보다 32% 늘었고, 전체 지출도 9.7% 많아요.")
        #expect(spans.count == 2)
        #expect(spans[0].kind == .increase)
    }

    @Test func neutralWhenNoDirectionKeywordInClause() {
        let spans = SentenceHighlighter.spans(in: "카페 지출이 지난달 같은 시점보다 32% 늘었고, 전체 지출도 9.7% 많아요.")
        #expect(spans[1].kind == .neutral)
    }

    @Test func detectsDecreaseKeyword() {
        let spans = SentenceHighlighter.spans(in: "식비가 지난달보다 8% 줄었어요.")
        #expect(spans.count == 1)
        #expect(spans[0].kind == .decrease)
    }

    @Test func detectsWonAmountPatternAsNeutralWithoutDirectionKeyword() {
        let spans = SentenceHighlighter.spans(in: "이번 달 총지출은 110,000원이에요.")
        #expect(spans.count == 1)
        #expect(spans[0].kind == .neutral)
    }

    @Test func wonAmountNearIncreaseKeywordIsIncrease() {
        let text = "총지출은 541,000원 초과했어요."
        let spans = SentenceHighlighter.spans(in: text)
        #expect(spans.count == 1)
        #expect(String(text[spans[0].range]) == "541,000원")
        #expect(spans[0].kind == .increase)
    }

    @Test func clauseBoundaryDoesNotLeakBetweenNumbers() {
        // "32%"의 절은 다음 쉼표까지("32% 늘었고")만 봐야 하므로, 뒤 절의 "줄었"이
        // 앞쪽 숫자의 분류에 영향을 주면 안 된다.
        let spans = SentenceHighlighter.spans(in: "카페는 32% 늘었고, 식비는 8% 줄었어요.")
        #expect(spans.count == 2)
        #expect(spans[0].kind == .increase)
        #expect(spans[1].kind == .decrease)
    }

    @Test func returnsEmptyForTextWithoutNumbers() {
        let spans = SentenceHighlighter.spans(in: "이번 주 카페를 줄이면 예산 안에 들어올 수 있어요.")
        #expect(spans.isEmpty)
    }

    @Test func spansAreSortedByPosition() {
        let spans = SentenceHighlighter.spans(in: "카페는 32% 늘었고, 식비는 8% 줄었어요.")
        #expect(spans[0].range.lowerBound < spans[1].range.lowerBound)
    }
}
