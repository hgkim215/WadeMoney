import Foundation

enum AppStoreLink {
    static func detailURL(
        appID: String,
        encodedSlug: String,
        country: String = "kr"
    ) -> URL? {
        guard !appID.isEmpty,
              appID.allSatisfy(\.isNumber),
              !encodedSlug.isEmpty else {
            return nil
        }

        return URL(string: "https://apps.apple.com/\(country)/app/\(encodedSlug)/id\(appID)?uo=4")
    }

    static func detailURL(from storeURLString: String) -> URL? {
        guard let url = URL(string: storeURLString),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host?.lowercased(),
              host == "apps.apple.com",
              appID(from: url) != nil else {
            return nil
        }

        return url
    }

    private static func appID(from url: URL) -> String? {
        url.pathComponents
            .lazy
            .compactMap { component -> String? in
                guard component.hasPrefix("id") else { return nil }
                let id = String(component.dropFirst(2))
                guard !id.isEmpty, id.allSatisfy(\.isNumber) else { return nil }
                return id
            }
            .first
    }
}
