//
//  Theme.swift
//  FuekiWallet
//
//  Created by Fueki Wallet Team
//

import UIKit

struct Theme {

    // MARK: - Colors

    struct Colors {

        // Primary Colors
        static let primary = UIColor(hex: "#6366F1") // Indigo
        static let primaryLight = UIColor(hex: "#818CF8")
        static let primaryDark = UIColor(hex: "#4F46E5")

        // Secondary Colors
        static let secondary = UIColor(hex: "#10B981") // Green
        static let secondaryLight = UIColor(hex: "#34D399")
        static let secondaryDark = UIColor(hex: "#059669")

        // Accent Colors
        static let accent = UIColor(hex: "#F59E0B") // Amber
        static let accentLight = UIColor(hex: "#FBBF24")
        static let accentDark = UIColor(hex: "#D97706")

        // Status Colors
        static let success = UIColor(hex: "#10B981")
        static let warning = UIColor(hex: "#F59E0B")
        static let error = UIColor(hex: "#EF4444")
        static let info = UIColor(hex: "#3B82F6")

        // Neutral Colors
        static let background = UIColor(hex: "#FFFFFF")
        static let surface = UIColor(hex: "#F9FAFB")
        static let surfaceSecondary = UIColor(hex: "#F3F4F6")

        // Text Colors
        static let text = UIColor(hex: "#111827")
        static let textSecondary = UIColor(hex: "#6B7280")
        static let textTertiary = UIColor(hex: "#9CA3AF")
        static let textInverted = UIColor(hex: "#FFFFFF")

        // Border Colors
        static let border = UIColor(hex: "#E5E7EB")
        static let borderLight = UIColor(hex: "#F3F4F6")
        static let borderDark = UIColor(hex: "#D1D5DB")

        // Shadow Colors
        static let shadow = UIColor(hex: "#000000", alpha: 0.1)
        static let shadowLight = UIColor(hex: "#000000", alpha: 0.05)
        static let shadowDark = UIColor(hex: "#000000", alpha: 0.2)

        // Dark Mode Colors
        static let backgroundDark = UIColor(hex: "#111827")
        static let surfaceDark = UIColor(hex: "#1F2937")
        static let surfaceSecondaryDark = UIColor(hex: "#374151")

        // Chart Colors
        static let chartGreen = UIColor(hex: "#10B981")
        static let chartRed = UIColor(hex: "#EF4444")
        static let chartBlue = UIColor(hex: "#3B82F6")
        static let chartYellow = UIColor(hex: "#F59E0B")
        static let chartPurple = UIColor(hex: "#8B5CF6")
        static let chartPink = UIColor(hex: "#EC4899")

        // Transaction Colors
        static let sent = UIColor(hex: "#EF4444")
        static let received = UIColor(hex: "#10B981")
        static let pending = UIColor(hex: "#F59E0B")
        static let failed = UIColor(hex: "#6B7280")
    }

    // MARK: - Fonts

    struct Fonts {

        // Display
        static let displayLarge = UIFont.systemFont(ofSize: 57, weight: .bold)
        static let displayMedium = UIFont.systemFont(ofSize: 45, weight: .bold)
        static let displaySmall = UIFont.systemFont(ofSize: 36, weight: .bold)

        // Headline
        static let headlineLarge = UIFont.systemFont(ofSize: 32, weight: .semibold)
        static let headline = UIFont.systemFont(ofSize: 24, weight: .semibold)
        static let headlineSmall = UIFont.systemFont(ofSize: 20, weight: .semibold)

        // Title
        static let titleLarge = UIFont.systemFont(ofSize: 22, weight: .medium)
        static let title = UIFont.systemFont(ofSize: 18, weight: .medium)
        static let titleSmall = UIFont.systemFont(ofSize: 16, weight: .medium)

        // Body
        static let bodyLarge = UIFont.systemFont(ofSize: 16, weight: .regular)
        static let body = UIFont.systemFont(ofSize: 14, weight: .regular)
        static let bodySmall = UIFont.systemFont(ofSize: 12, weight: .regular)

        // Label
        static let labelLarge = UIFont.systemFont(ofSize: 14, weight: .medium)
        static let label = UIFont.systemFont(ofSize: 12, weight: .medium)
        static let labelSmall = UIFont.systemFont(ofSize: 11, weight: .medium)

        // Monospace (for addresses, hashes)
        static let monospaceLarge = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        static let monospace = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        static let monospaceSmall = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)

        // Number (for amounts)
        static let numberLarge = UIFont.monospacedDigitSystemFont(ofSize: 32, weight: .semibold)
        static let number = UIFont.monospacedDigitSystemFont(ofSize: 24, weight: .semibold)
        static let numberSmall = UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .semibold)
    }

    // MARK: - Spacing

    struct Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    struct CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 999
    }

    // MARK: - Shadow

    struct Shadow {
        static let small = ShadowStyle(
            color: Colors.shadow,
            offset: CGSize(width: 0, height: 1),
            radius: 2,
            opacity: 0.05
        )

        static let medium = ShadowStyle(
            color: Colors.shadow,
            offset: CGSize(width: 0, height: 2),
            radius: 4,
            opacity: 0.1
        )

        static let large = ShadowStyle(
            color: Colors.shadow,
            offset: CGSize(width: 0, height: 4),
            radius: 8,
            opacity: 0.15
        )
    }

    struct ShadowStyle {
        let color: UIColor
        let offset: CGSize
        let radius: CGFloat
        let opacity: Float
    }

    // MARK: - Border

    struct Border {
        static let thin: CGFloat = 0.5
        static let regular: CGFloat = 1
        static let thick: CGFloat = 2
    }

    // MARK: - Animation

    struct Animation {
        static let fast: TimeInterval = 0.2
        static let normal: TimeInterval = 0.3
        static let slow: TimeInterval = 0.5
    }

    // MARK: - Apply Theme

    static func apply() {
        applyNavigationBar()
        applyTabBar()
        applyButtons()
        applyTextFields()
        applyTableView()
    }

    private static func applyNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Colors.background
        appearance.shadowColor = Colors.border

        appearance.titleTextAttributes = [
            .foregroundColor: Colors.text,
            .font: Fonts.headline
        ]

        appearance.largeTitleTextAttributes = [
            .foregroundColor: Colors.text,
            .font: Fonts.headlineLarge
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = Colors.primary
    }

    private static func applyTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Colors.surface

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = Colors.textSecondary
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: Colors.textSecondary,
            .font: Fonts.labelSmall
        ]

        itemAppearance.selected.iconColor = Colors.primary
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: Colors.primary,
            .font: Fonts.labelSmall
        ]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    private static func applyButtons() {
        UIButton.appearance().tintColor = Colors.primary
    }

    private static func applyTextFields() {
        UITextField.appearance().tintColor = Colors.primary
    }

    private static func applyTableView() {
        UITableView.appearance().backgroundColor = Colors.background
        UITableView.appearance().separatorColor = Colors.border
    }

    // MARK: - Helper Methods

    static func applyShadow(to view: UIView, style: ShadowStyle) {
        view.layer.shadowColor = style.color.cgColor
        view.layer.shadowOffset = style.offset
        view.layer.shadowRadius = style.radius
        view.layer.shadowOpacity = style.opacity
    }

    static func applyCornerRadius(to view: UIView, radius: CGFloat, corners: UIRectCorner = .allCorners) {
        if corners == .allCorners {
            view.layer.cornerRadius = radius
            view.layer.masksToBounds = true
        } else {
            let path = UIBezierPath(
                roundedRect: view.bounds,
                byRoundingCorners: corners,
                cornerRadii: CGSize(width: radius, height: radius)
            )
            let mask = CAShapeLayer()
            mask.path = path.cgPath
            view.layer.mask = mask
        }
    }

    static func applyBorder(to view: UIView, color: UIColor, width: CGFloat) {
        view.layer.borderColor = color.cgColor
        view.layer.borderWidth = width
    }
}

// MARK: - UIColor Extension

extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    func lighter(by percentage: CGFloat = 0.2) -> UIColor {
        return adjust(by: abs(percentage))
    }

    func darker(by percentage: CGFloat = 0.2) -> UIColor {
        return adjust(by: -abs(percentage))
    }

    func adjust(by percentage: CGFloat) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return UIColor(
            red: min(red + percentage, 1.0),
            green: min(green + percentage, 1.0),
            blue: min(blue + percentage, 1.0),
            alpha: alpha
        )
    }
}
