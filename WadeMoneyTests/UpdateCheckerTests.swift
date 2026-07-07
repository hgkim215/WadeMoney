import Foundation
import Testing
@testable import WadeMoney

struct UpdateCheckerTests {
    private func defaults(_ name: String = UUID().uuidString) -> UserDefaults {
        let suiteName = "UpdateCheckerTests-\(name)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func json(version: String, url: String = "https://apps.apple.com/kr/app/wademoney/id1234567890?uo=4") -> Data {
        """
        {
          "resultCount": 1,
          "results": [
            {
              "version": "\(version)",
              "trackViewUrl": "\(url)"
            }
          ]
        }
        """.data(using: .utf8)!
    }

    @Test func returnsInfoWhenLookupVersionIsNewer() async {
        let defaults = defaults("newer")
        var requestedURL: URL?
        let checker = UpdateChecker(
            bundleID: "com.kimhyeongi.WadeMoney",
            currentVersion: "1.0.0",
            defaults: defaults,
            now: { Date(timeIntervalSince1970: 1_000) },
            fetch: { url in
                requestedURL = url
                return json(version: "1.0.1")
            }
        )

        let info = await checker.check()

        #expect(info == UpdateInfo(version: "1.0.1", storeURL: URL(string: "https://apps.apple.com/kr/app/wademoney/id1234567890?uo=4")!))
        #expect(requestedURL?.absoluteString.contains("bundleId=com.kimhyeongi.WadeMoney") == true)
        #expect(requestedURL?.absoluteString.contains("country=kr") == true)
    }

    @Test func returnsNilWhenLookupVersionIsSame() async {
        let checker = UpdateChecker(
            bundleID: "com.kimhyeongi.WadeMoney",
            currentVersion: "1.0.0",
            defaults: defaults("same"),
            now: { Date(timeIntervalSince1970: 1_000) },
            fetch: { _ in json(version: "1.0.0") }
        )

        let info = await checker.check()

        #expect(info == nil)
    }

    @Test func returnsNilForMalformedJSON() async {
        let checker = UpdateChecker(
            bundleID: "com.kimhyeongi.WadeMoney",
            currentVersion: "1.0.0",
            defaults: defaults("malformed"),
            now: { Date(timeIntervalSince1970: 1_000) },
            fetch: { _ in Data("not-json".utf8) }
        )

        let info = await checker.check()

        #expect(info == nil)
    }

    @Test func returnsNilForInvalidStoreURL() async {
        let checker = UpdateChecker(
            bundleID: "com.kimhyeongi.WadeMoney",
            currentVersion: "1.0.0",
            defaults: defaults("bad-url"),
            now: { Date(timeIntervalSince1970: 1_000) },
            fetch: { _ in json(version: "2.0.0", url: "not a url") }
        )

        let info = await checker.check()

        #expect(info == nil)
    }

    @Test func returnsNilForAppStoreURLWithoutAppID() async {
        let checker = UpdateChecker(
            bundleID: "com.kimhyeongi.WadeMoney",
            currentVersion: "1.0.0",
            defaults: defaults("missing-id"),
            now: { Date(timeIntervalSince1970: 1_000) },
            fetch: { _ in json(version: "2.0.0", url: "https://apps.apple.com/kr/search?term=WadeMoney") }
        )

        let info = await checker.check()

        #expect(info == nil)
    }

    @Test func respectsTwentyFourHourGate() async {
        let defaults = defaults("gate")
        var fetchCount = 0
        var now = Date(timeIntervalSince1970: 1_000)
        let checker = UpdateChecker(
            bundleID: "com.kimhyeongi.WadeMoney",
            currentVersion: "1.0.0",
            defaults: defaults,
            now: { now },
            fetch: { _ in
                fetchCount += 1
                return json(version: "2.0.0")
            }
        )

        _ = await checker.check()
        now = Date(timeIntervalSince1970: 1_000 + 60)
        let second = await checker.check()
        now = Date(timeIntervalSince1970: 1_000 + 24 * 60 * 60 + 1)
        _ = await checker.check()

        #expect(second == nil)
        #expect(fetchCount == 2)
    }
}
