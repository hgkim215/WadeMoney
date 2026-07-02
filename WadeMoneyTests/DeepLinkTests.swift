import Foundation
import Testing
@testable import WadeMoney

struct DeepLinkTests {
    @Test func buildsAndParsesCategoryDeepLink() {
        let id = UUID()
        let url = DeepLink.quickAdd(categoryID: id)
        #expect(DeepLink.isQuickAdd(url))
        #expect(DeepLink.categoryID(from: url) == id)
    }

    @Test func buildsDeepLinkWithoutCategoryForManualEntry() {
        let url = DeepLink.quickAdd(categoryID: nil)
        #expect(DeepLink.isQuickAdd(url))
        #expect(DeepLink.categoryID(from: url) == nil)
    }

    @Test func rejectsUnrelatedURL() {
        let url = URL(string: "https://example.com")!
        #expect(!DeepLink.isQuickAdd(url))
        #expect(DeepLink.categoryID(from: url) == nil)
    }
}
