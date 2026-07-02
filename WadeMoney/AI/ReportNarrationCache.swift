import Foundation

/// 리포트 내레이션 캐시. 입력이 같으면(=데이터가 안 변했으면) 온디바이스 생성 없이 즉시 재사용한다.
/// 리포트는 현재 월 하나만 다루므로 최신 1건만 보관한다.
final class ReportNarrationCache {
    private let defaults: UserDefaults
    private static let storageKey = "aiReport.narrationCache.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func narration(for key: String) -> ReportNarration? {
        guard
            let dict = defaults.dictionary(forKey: Self.storageKey) as? [String: String],
            dict["key"] == key,
            let summary = dict["summary"], let tip = dict["tip"]
        else { return nil }
        return ReportNarration(summarySentence: summary, tipSentence: tip)
    }

    func store(_ narration: ReportNarration, for key: String) {
        defaults.set(
            ["key": key, "summary": narration.summarySentence, "tip": narration.tipSentence],
            forKey: Self.storageKey
        )
    }
}
