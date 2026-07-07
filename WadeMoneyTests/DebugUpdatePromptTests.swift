#if DEBUG
import Foundation
import Testing
@testable import WadeMoney

struct DebugUpdatePromptTests {
    @Test func previewUpdateInfoUsesVisibleFutureVersionAndAppStoreDetailURL() {
        let info = DebugUpdatePrompt.updateInfo

        #expect(info.version == "999.0")
        #expect(info.storeURL.absoluteString == "https://apps.apple.com/kr/app/wademoney-%EA%B0%84%EB%8B%A8-%EC%8B%AC%ED%94%8C-%EA%B0%80%EA%B3%84%EB%B6%80/id6786733784?uo=4")
    }
}
#endif
