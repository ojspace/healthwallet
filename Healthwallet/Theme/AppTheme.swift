import SwiftUI

enum AppTheme {
    // MARK: - Colors
    enum Colors {
        static let primary = Color("AccentBlue", bundle: nil)
        static let primaryFallback = Color(red: 0.24, green: 0.43, blue: 0.53) // #3E6E88
        static let background = Color(.systemGroupedBackground)
        static let surface = Color(.secondarySystemGroupedBackground)
        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)

        static let statusLow = Color.yellow
        static let statusHigh = Color.red
        static let statusOptimal = Color.green
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radius
    enum Radius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }
}
