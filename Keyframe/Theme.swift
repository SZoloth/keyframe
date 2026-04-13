import SwiftUI

enum Theme {
    enum Colors {
        static let primary = Color.primary
        static let secondary = Color.secondary
        static let accent = Color.accentColor
        static let background = Color(.windowBackgroundColor)
        static let secondaryBackground = Color(.controlBackgroundColor)
        static let tertiaryBackground = Color(.quaternarySystemFill)
        static let separator = Color(.separatorColor)
    }

    enum Typography {
        static let largeTitle = Font.largeTitle
        static let title = Font.title2.weight(.semibold)
        static let headline = Font.headline
        static let subheadline = Font.subheadline
        static let body = Font.body
        static let caption = Font.caption
        static let caption2 = Font.caption2
        static let mono = Font.system(.body, design: .monospaced)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let full: CGFloat = 9999
    }

    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8)
    }
}
