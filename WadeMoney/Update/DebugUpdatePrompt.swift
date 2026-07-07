#if DEBUG
import Foundation

extension Notification.Name {
    static let debugShowUpdatePrompt = Notification.Name("debugShowUpdatePrompt")
}

enum DebugUpdatePrompt {
    static let previewVersion = "999.0"

    static var updateInfo: UpdateInfo {
        UpdateInfo(
            version: previewVersion,
            storeURL: AppStoreLink.detailURL(
                appID: "6786733784",
                encodedSlug: "wademoney-%EA%B0%84%EB%8B%A8-%EC%8B%AC%ED%94%8C-%EA%B0%80%EA%B3%84%EB%B6%80"
            )!
        )
    }

    static func requestPreview() {
        NotificationCenter.default.post(name: .debugShowUpdatePrompt, object: nil)
    }
}
#endif
