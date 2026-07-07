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
            storeURL: URL(string: "https://apps.apple.com/kr/search?term=WadeMoney")!
        )
    }

    static func requestPreview() {
        NotificationCenter.default.post(name: .debugShowUpdatePrompt, object: nil)
    }
}
#endif
