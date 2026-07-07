#if DEBUG
import Foundation
import Testing
@testable import WadeMoney

struct DebugUpdatePromptTests {
    @Test func previewUpdateInfoUsesVisibleFutureVersionAndAppStoreURL() {
        let info = DebugUpdatePrompt.updateInfo

        #expect(info.version == "999.0")
        #expect(info.storeURL.scheme == "https")
        #expect(info.storeURL.host == "apps.apple.com")
    }
}
#endif
