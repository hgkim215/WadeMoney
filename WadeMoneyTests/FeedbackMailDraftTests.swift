import Testing
@testable import WadeMoney

struct FeedbackMailDraftTests {
    @Test func buildsDraftWithRecipientSubjectAndDeviceContext() {
        let draft = FeedbackMailDraft.make(
            appVersion: "1.0",
            buildNumber: "7",
            deviceModel: "iPhone17,3",
            systemVersion: "26.0"
        )

        #expect(draft.recipients == ["hgkim215@gmail.com"])
        #expect(draft.subject == "[WadeMoney] 앱 개선 의견")
        #expect(draft.body.contains("앱 버전: 1.0 (7)"))
        #expect(draft.body.contains("기기: iPhone17,3"))
        #expect(draft.body.contains("iOS: 26.0"))
        #expect(draft.body.contains("[의견]"))
    }
}
