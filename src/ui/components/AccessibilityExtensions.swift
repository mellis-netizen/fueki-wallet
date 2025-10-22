//
//  AccessibilityExtensions.swift
//  Fueki Wallet
//
//  Accessibility helpers for improved VoiceOver and accessibility support
//

import SwiftUI

// MARK: - Accessibility Modifiers

extension View {
    /// Add semantic label for VoiceOver
    func accessibilityLabel(_ label: String, hint: String? = nil) -> some View {
        self.modifier(AccessibilityLabelModifier(label: label, hint: hint))
    }

    /// Mark as interactive button for accessibility
    func accessibleButton(label: String, hint: String? = nil, traits: AccessibilityTraits = []) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits([.isButton] + traits)
    }

    /// Mark as currency amount for proper reading
    func accessibleCurrency(amount: Decimal, currency: String) -> some View {
        self.accessibilityLabel("\(amount.formatted()) \(currency)")
    }

    /// Add accessibility sorting for better navigation
    func accessibilitySortPriority(_ priority: Double) -> some View {
        self.accessibilitySortPriority(priority)
    }
}

struct AccessibilityLabelModifier: ViewModifier {
    let label: String
    let hint: String?

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
}

// MARK: - Dynamic Type Support

extension View {
    /// Scale font based on accessibility settings
    func dynamicTypeSize(_ size: DynamicTypeSize = .xLarge) -> some View {
        self.dynamicTypeSize(...size)
    }

    /// Limit scaling for critical UI elements
    func limitedDynamicType(min: DynamicTypeSize = .small, max: DynamicTypeSize = .xxxLarge) -> some View {
        self.dynamicTypeSize(min...max)
    }
}

// MARK: - Color Contrast Helpers

extension Color {
    /// Check if color meets WCAG AA contrast ratio
    func meetsWCAGContrast(with background: Color) -> Bool {
        let ratio = contrastRatio(with: background)
        return ratio >= 4.5 // WCAG AA standard
    }

    /// Calculate contrast ratio between two colors
    func contrastRatio(with color: Color) -> Double {
        let l1 = relativeLuminance()
        let l2 = color.relativeLuminance()

        let lighter = max(l1, l2)
        let darker = min(l1, l2)

        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance() -> Double {
        guard let components = UIColor(self).cgColor.components else {
            return 0
        }

        let r = linearize(components[0])
        let g = linearize(components[1])
        let b = linearize(components[2])

        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private func linearize(_ value: CGFloat) -> Double {
        let v = Double(value)
        if v <= 0.03928 {
            return v / 12.92
        }
        return pow((v + 0.055) / 1.055, 2.4)
    }
}

// MARK: - Reduced Motion Support

extension View {
    /// Conditionally apply animation based on accessibility settings
    func accessibleAnimation<V: Equatable>(
        _ animation: Animation? = .default,
        value: V
    ) -> some View {
        if UIAccessibility.isReduceMotionEnabled {
            return AnyView(self)
        } else {
            return AnyView(self.animation(animation, value: value))
        }
    }

    /// Provide alternative for motion-heavy transitions
    func reducedMotionTransition(
        active: AnyTransition,
        reduced: AnyTransition = .opacity
    ) -> some View {
        self.transition(
            UIAccessibility.isReduceMotionEnabled ? reduced : active
        )
    }
}

// MARK: - VoiceOver Grouping

extension View {
    /// Group related elements for VoiceOver
    func accessibilityElement(children: AccessibilityChildBehavior = .combine) -> some View {
        self.accessibilityElement(children: children)
    }

    /// Create custom accessibility group
    func accessibilityGroup() -> some View {
        self.accessibilityElement(children: .combine)
    }
}

// MARK: - Accessibility Announcements

struct AccessibilityAnnouncement {
    /// Post accessibility announcement
    static func announce(_ message: String, delay: TimeInterval = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    /// Announce screen change
    static func screenChanged() {
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }

    /// Announce layout change
    static func layoutChanged() {
        UIAccessibility.post(notification: .layoutChanged, argument: nil)
    }
}

// MARK: - High Contrast Support

extension View {
    func adaptiveContrast(
        normal: Color,
        highContrast: Color
    ) -> some View {
        self.foregroundColor(
            UIAccessibility.isDarkerSystemColorsEnabled ? highContrast : normal
        )
    }
}
