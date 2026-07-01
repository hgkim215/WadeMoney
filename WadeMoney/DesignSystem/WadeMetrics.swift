import SwiftUI

enum WadeRadius {
    static let card: CGFloat = 24
    static let listCard: CGFloat = 20
    static let control: CGFloat = 16
    static let segment: CGFloat = 14
    static let iconTile: CGFloat = 12
    static let pill: CGFloat = 999
    static let sheet: CGFloat = 30
    static let fab: CGFloat = 20
}

enum WadeSpacing {
    static let screenH: CGFloat = 18
    static let cardGap: CGFloat = 14
    static let cardPadding: CGFloat = 20
    static let contentTop: CGFloat = 60
    static let contentBottom: CGFloat = 104
}

struct WadeShadow {
    static func card(_ scheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
        (WadeColors.shadow(scheme), 26, 10)
    }
    static func list(_ scheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
        (WadeColors.shadow(scheme), 22, 8)
    }
}
