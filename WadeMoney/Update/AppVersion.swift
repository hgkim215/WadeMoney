enum AppVersion {
    static func isVersion(_ latest: String, newerThan current: String) -> Bool {
        let latestParts = numericParts(latest)
        let currentParts = numericParts(current)
        let count = max(latestParts.count, currentParts.count)

        for index in 0..<count {
            let latestValue = index < latestParts.count ? latestParts[index] : 0
            let currentValue = index < currentParts.count ? currentParts[index] : 0
            if latestValue != currentValue {
                return latestValue > currentValue
            }
        }

        return false
    }

    private static func numericParts(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0) ?? 0 }
    }
}
