import Foundation

struct FeedbackMailDraft: Equatable {
    static let supportEmail = "hgkim215@gmail.com"

    let recipients: [String]
    let subject: String
    let body: String

    static func make(appVersion: String, buildNumber: String, deviceModel: String, systemVersion: String) -> FeedbackMailDraft {
        FeedbackMailDraft(
            recipients: [supportEmail],
            subject: "[WadeMoney] 앱 개선 의견",
            body: """
            안녕하세요, WadeMoney 개선 의견을 보냅니다.

            [의견]
            - 

            [앱 정보]
            - 앱 버전: \(appVersion) (\(buildNumber))
            - 기기: \(deviceModel)
            - iOS: \(systemVersion)
            """
        )
    }
}
