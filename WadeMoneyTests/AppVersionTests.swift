import Testing
@testable import WadeMoney

struct AppVersionTests {
    @Test func newerPatchIsNewer() {
        #expect(AppVersion.isVersion("1.0.1", newerThan: "1.0.0") == true)
    }

    @Test func newerMinorIsNewer() {
        #expect(AppVersion.isVersion("1.2.0", newerThan: "1.1.9") == true)
    }

    @Test func newerMajorIsNewer() {
        #expect(AppVersion.isVersion("2.0", newerThan: "1.9.9") == true)
    }

    @Test func sameVersionIsNotNewer() {
        #expect(AppVersion.isVersion("1.0.0", newerThan: "1.0.0") == false)
    }

    @Test func olderVersionIsNotNewer() {
        #expect(AppVersion.isVersion("1.0.0", newerThan: "1.0.1") == false)
    }

    @Test func missingComponentsCompareAsZero() {
        #expect(AppVersion.isVersion("1.4", newerThan: "1.4.0") == false)
        #expect(AppVersion.isVersion("1.4.1", newerThan: "1.4") == true)
    }

    @Test func comparesNumericallyInsteadOfLexically() {
        #expect(AppVersion.isVersion("1.10.0", newerThan: "1.9.0") == true)
    }

    @Test func nonNumericComponentsFallBackToZero() {
        #expect(AppVersion.isVersion("1.0.0", newerThan: "1.x.0") == false)
        #expect(AppVersion.isVersion("1.0.1", newerThan: "1.x.0") == true)
    }
}
