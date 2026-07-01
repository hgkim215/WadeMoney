import Testing
@testable import WadeMoney

struct SmokeTests {
    @Test func appIDsAreConfigured() {
        #expect(AppIDs.appGroup == "group.com.kimhyeongi.WadeMoney")
        #expect(AppIDs.iCloudContainer == "iCloud.com.kimhyeongi.WadeMoney")
    }
}
