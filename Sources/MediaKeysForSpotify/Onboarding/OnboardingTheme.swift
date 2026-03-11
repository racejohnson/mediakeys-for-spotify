import SwiftUI

enum OnboardingTheme {
    // MARK: - Colors

    static let spotifyGreen = Color(red: 0.114, green: 0.725, blue: 0.329)
    static let bodyText = Color.black.opacity(0.7)
    static let descriptionText = Color.black.opacity(0.6)
    static let labelText = Color.black.opacity(0.5)
    static let mutedText = Color.black.opacity(0.4)

    // MARK: - Typography

    static let heroTitle: Font = .system(size: 28, weight: .bold)
    static let sectionTitle: Font = .system(size: 22, weight: .bold)
    static let featureTitle: Font = .system(size: 15, weight: .semibold)
    static let body: Font = .system(size: 15)
    static let small: Font = .system(size: 13)
    static let uppercaseLabel: Font = .system(size: 11, weight: .medium)

    // MARK: - Spacing

    static let windowPadding: CGFloat = 32
    static let sectionSpacing: CGFloat = 24
    static let itemSpacing: CGFloat = 16

    // MARK: - Dimensions

    static let windowWidth: CGFloat = 600
    static let windowHeight: CGFloat = 520
    static let stepIndicatorSize: CGFloat = 24
    static let stepIndicatorRadius: CGFloat = 6
}
