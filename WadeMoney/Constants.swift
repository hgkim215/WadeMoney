import Foundation

enum AppIDs {
    static let appGroup = "group.com.kimhyeongi.WadeMoney"
    static let iCloudContainer = "iCloud.com.kimhyeongi.WadeMoney"
}

/// gh-pages 브랜치로 게시된 정책 페이지(GitHub Pages).
enum WadeMoneyLegal {
    static let privacyPolicy = URL(string: "https://hgkim215.github.io/WadeMoney/privacy-policy.html")!
    static let termsOfService = URL(string: "https://hgkim215.github.io/WadeMoney/terms-of-service.html")!
}
