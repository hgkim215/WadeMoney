import SwiftUI

/// AI가 생성한 문장(또는 결정적 대체 문장) 안의 숫자를 증가/감소/중립으로 분류한다.
enum HighlightKind: Equatable {
    case increase
    case decrease
    case neutral
}

/// 원문 문자열 안에서 강조할 구간과 그 분류.
struct HighlightSpan: Equatable {
    let range: Range<String.Index>
    let kind: HighlightKind
}

/// AI 리포트 문장 속 숫자(백분율·원화 금액)를 찾아 굵게+색깔로 강조하기 위한 순수 로직.
/// SwiftUI 타입에 의존하지 않는 함수라 UI 없이 테스트 가능하다.
enum SentenceHighlighter {
    nonisolated(unsafe) private static let percentPattern = /\d+(\.\d+)?%/
    nonisolated(unsafe) private static let wonPattern = /[\d,]+원/
    private static let increaseKeywords = ["늘었", "증가", "올랐", "초과"]
    private static let decreaseKeywords = ["줄었", "감소", "내렸", "절약"]

    /// text 안에서 백분율·원화 금액 패턴을 모두 찾아 위치 순으로 정렬하고, 각각을
    /// 같은 절(다음 쉼표·마침표 전까지) 안의 방향 키워드로 분류한다.
    static func spans(in text: String) -> [HighlightSpan] {
        let percentRanges = Array(text.ranges(of: percentPattern))
        let wonRanges = Array(text.ranges(of: wonPattern))
        let allRanges = (percentRanges + wonRanges).sorted { $0.lowerBound < $1.lowerBound }
        return allRanges.map { HighlightSpan(range: $0, kind: classify($0, in: text)) }
    }

    private static func classify(_ range: Range<String.Index>, in text: String) -> HighlightKind {
        let rest = text[range.upperBound...]
        let clauseEnd = rest.firstIndex { $0 == "," || $0 == "." } ?? text.endIndex
        let clause = text[range.upperBound..<clauseEnd]
        if increaseKeywords.contains(where: { clause.contains($0) }) { return .increase }
        if decreaseKeywords.contains(where: { clause.contains($0) }) { return .decrease }
        return .neutral
    }
}
