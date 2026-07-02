import Foundation

enum DeepLink {
    static let scheme = "wademoney"

    /// category가 nil이면 카테고리 미선택 상태로 빠른 입력 시트를 연다("직접" 칩).
    static func quickAdd(categoryID: UUID?) -> URL {
        var comps = URLComponents()
        comps.scheme = scheme
        comps.host = "quickadd"
        if let categoryID {
            comps.queryItems = [URLQueryItem(name: "category", value: categoryID.uuidString)]
        }
        return comps.url!
    }

    static func isQuickAdd(_ url: URL) -> Bool {
        url.scheme == scheme && url.host == "quickadd"
    }

    static func categoryID(from url: URL) -> UUID? {
        guard isQuickAdd(url) else { return nil }
        guard let item = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "category" }) else { return nil }
        return item.value.flatMap { UUID(uuidString: $0) }
    }
}
