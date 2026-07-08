import Foundation

struct UpdateInfo: Equatable, Sendable {
    let version: String
    let storeURL: URL
}

struct UpdateChecker: @unchecked Sendable {
    typealias Fetch = (URL) async throws -> Data

    private let bundleID: String?
    private let currentVersion: String?
    private let defaults: UserDefaults
    private let now: () -> Date
    private let country: String
    private let interval: TimeInterval
    private let fetch: Fetch
    private let lastCheckKey = "lastAppStoreUpdateCheckDate"

    init(
        bundleID: String? = Bundle.main.bundleIdentifier,
        currentVersion: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        country: String = "kr",
        interval: TimeInterval = 24 * 60 * 60,
        fetch: @escaping Fetch = { url in
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        }
    ) {
        self.bundleID = bundleID
        self.currentVersion = currentVersion
        self.defaults = defaults
        self.now = now
        self.country = country
        self.interval = interval
        self.fetch = fetch
    }

    func check() async -> UpdateInfo? {
        guard shouldCheckNow() else { return nil }

        guard let bundleID,
              let currentVersion,
              var components = URLComponents(string: "https://itunes.apple.com/lookup") else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "country", value: country)
        ]

        guard let url = components.url else { return nil }

        do {
            let data = try await fetch(url)
            let response = try JSONDecoder().decode(LookupResponse.self, from: data)
            // 응답을 성공적으로 받아 해석한 뒤에만 확인 시각을 기록한다 —
            // 호출 전에 기록하면 오프라인 등으로 실패한 확인이 24시간 재확인까지 삼킨다.
            defaults.set(now(), forKey: lastCheckKey)
            guard let result = response.results.first,
                  let storeURL = AppStoreLink.detailURL(from: result.trackViewUrl),
                  AppVersion.isVersion(result.version, newerThan: currentVersion) else {
                return nil
            }
            return UpdateInfo(version: result.version, storeURL: storeURL)
        } catch {
            return nil
        }
    }

    private func shouldCheckNow() -> Bool {
        guard let last = defaults.object(forKey: lastCheckKey) as? Date else {
            return true
        }
        return now().timeIntervalSince(last) >= interval
    }
}

private struct LookupResponse: Decodable {
    let results: [LookupResult]
}

private struct LookupResult: Decodable {
    let version: String
    let trackViewUrl: String
}
