import SwiftUI

// MARK: - SierraTheme

/// Master design-token namespace for the Sierra Fleet Management System.
/// Every color, spacing, radius, and shadow value in the app is defined here.
/// No other file should hardcode hex values, font sizes, or magic numbers.
public enum SierraTheme {

    // MARK: - Colors

    public enum Colors {

        // ── Brand Core ──

        /// #0D1F3C - NavigationBar, primary text, headers
        public static let summitNavy   = Color("SummitNavy")
        /// #1A3A6B - card surfaces, tab bar dark bg
        public static let sierraBlue   = Color("SierraBlue")
        /// Primary interactive accent with optional color-blind high-contrast mode.
        public static var ember: Color { SierraAccessibilityPalette.accent }
        /// Accent tint.
        public static var emberLight: Color { SierraAccessibilityPalette.accentLight.opacity(0.12) }
        /// Accent pressed/strong variant.
        public static var emberDark: Color { SierraAccessibilityPalette.accentDark }
        /// Success color. Switches to a color-blind-safe tone when enabled.
        public static var alpineMint: Color { SierraAccessibilityPalette.success }
        /// #4DCFB3 - mint tint on dark bg
        public static let alpineLight  = Color("AlpineLight")
        /// #078A6C - mint pressed / dark mode text
        public static let alpineDark   = Color("AlpineDark")

        // ── Standard UI (Vivid & Premium) ──

        /// Primary brand orange — CTAs, accents, active states
        public static var appOrange: Color { SierraAccessibilityPalette.accent }
        /// Deep orange — gradient dark end, pressed states
        public static var appDeepOrange: Color { SierraAccessibilityPalette.accentDark }
        /// Warm amber — gradient endpoints
        public static var appAmber: Color { SierraAccessibilityPalette.accentLight }
        /// Standardized app background
        public static let appSurface   = Color(.systemGroupedBackground)
        /// Standardized card background
        public static let appCardBg    = Color(.secondarySystemGroupedBackground)

        // ── Neutrals ──

        /// #F4F7FB - app background, table bg, grouped list bg (NOT card surface)
        public static let snowfield    = Color("Snowfield")
        /// #E2E8F0 - dividers, inactive borders, disabled states
        public static let cloud        = Color("Cloud")
        /// #CBD5E1 - secondary borders, outline button border
        public static let mist         = Color("Mist")
        /// #64748B - secondary labels, captions, placeholders, timestamps
        public static let granite      = Color("Granite")
        /// #334155 - primary body text
        public static let slate        = Color("Slate")
        /// #0A0F1E - dark mode base background
        public static let obsidian     = Color("Obsidian")

        // ── Semantic / Status ──

        /// Success - alias for alpineMint
        public static var success: Color { SierraAccessibilityPalette.success }
        /// #F59E0B - expiring docs, pending approval, in-maintenance
        public static var warning: Color { SierraAccessibilityPalette.warning }
        /// #EF4444 - destructive buttons, expired docs, cancelled, failed inspection
        public static var danger: Color { SierraAccessibilityPalette.danger }
        /// #3B82F6 - informational states, scheduled/pending trip
        public static var info: Color { SierraAccessibilityPalette.info }

        // ── Adaptive (Light / Dark) ──

        /// light: System Grouped Background, dark: Obsidian (#0A0F1E)
        public static let appBackground  = Color(.systemGroupedBackground)
        /// light: #FFFFFF, dark: #161C2D
        public static let cardSurface    = Color("CardSurface")
        /// light: SummitNavy (#0D1F3C), dark: #FFFFFF
        public static let primaryText    = Color("PrimaryText")
        /// light: Granite (#64748B), dark: rgba(255,255,255,0.40)
        public static let secondaryText  = Color("SecondaryText")
        /// light: Cloud (#E2E8F0), dark: rgba(255,255,255,0.08)
        public static let divider        = Color("Divider")
        /// light: SummitNavy (#0D1F3C), dark: #111827
        public static let navBarBg       = Color("NavBarBg")
    }

    // MARK: - Spacing

    public enum Spacing {
        public static let xxs:     CGFloat = 4
        public static let xs:      CGFloat = 8
        public static let sm:      CGFloat = 12
        public static let md:      CGFloat = 16
        public static let lg:      CGFloat = 20
        public static let xl:      CGFloat = 24
        public static let xxl:     CGFloat = 32
        public static let xxxl:    CGFloat = 48
        public static let section: CGFloat = 64
    }

    // MARK: - Radius

    public enum Radius {
        public static let xs:     CGFloat = 6
        public static let sm:     CGFloat = 8
        public static let md:     CGFloat = 12
        public static let lg:     CGFloat = 16
        public static let xl:     CGFloat = 20
        public static let xxl:    CGFloat = 28
        public static let card:   CGFloat = 20
        public static let badge:  CGFloat = 20
        public static let button: CGFloat = 16
        public static let avatar: CGFloat = 12
    }

    // MARK: - Shadow

    public enum Shadow {
        /// Card-level elevation - subtle drop
        public static let card  = SierraShadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
        /// Modal / sheet elevation
        public static let modal = SierraShadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        /// Navigation bar elevation
        public static let nav   = SierraShadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
    }

    // MARK: - Typography

    // TODO: See SierraFont.swift - full type scale defined in Phase 2.
}

// MARK: - SierraShadow

/// Reusable shadow configuration struct consumed by `.sierraShadow()` modifier.
public struct SierraShadow {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat
}

// MARK: - View + SierraShadow

extension View {
    /// Applies a `SierraShadow` preset.
    func sierraShadow(_ shadow: SierraShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - Semantic Status Colors

extension Color {
    /// Vehicle active, trip in-progress, driver available
    static var statusActive: Color { SierraTheme.Colors.alpineMint }
    /// Vehicle idle, paused
    static let statusIdle      = Color.gray
    /// Trip scheduled, awaiting
    static var statusScheduled: Color { SierraTheme.Colors.info }
    /// Expiring docs, pending review, in-maintenance
    static var statusWarning: Color { SierraTheme.Colors.warning }
    /// Cancelled, expired, emergency, breakdown
    static var statusDanger: Color { SierraTheme.Colors.danger }
    /// Trip completed, resolved
    static let statusCompleted = Color.secondary

    // ── Driver UI Design Tokens (FMS_SS reference) ──

    /// Primary brand orange — CTAs, accents, active states
    static var appOrange: Color { SierraTheme.Colors.appOrange }
    /// Warm amber — gradient endpoints, slider knob start
    static var appAmber: Color { SierraTheme.Colors.appAmber }
    /// Deep orange — gradient dark end, pressed states
    static var appDeepOrange: Color { SierraTheme.Colors.appDeepOrange }
    /// Light neutral surface — screen backgrounds
    static let appSurface     = Color(.systemGroupedBackground)
    /// Card background (white)
    static let appCardBg      = Color(.secondarySystemGroupedBackground)
    /// Primary text — near-black
    static let appTextPrimary = Color.primary
    /// Secondary text — gray captions
    static let appTextSecondary = Color.secondary
    /// Divider / separator lines
    static let appDivider     = Color(.separator)
}

// MARK: - TripPriority UI Helpers

extension TripPriority {
    var color: Color {
        switch self {
        case .urgent: return SierraTheme.Colors.danger
        case .high:   return Color.appOrange
        case .normal: return SierraTheme.Colors.info
        case .low:    return Color.appTextSecondary
        }
    }

    var bgColor: Color {
        switch self {
        case .urgent: return SierraTheme.Colors.danger.opacity(0.10)
        case .high:   return Color.appOrange.opacity(0.10)
        case .normal: return SierraTheme.Colors.info.opacity(0.10)
        case .low:    return Color.appTextSecondary.opacity(0.10)
        }
    }

    var borderColor: Color {
        switch self {
        case .urgent: return SierraTheme.Colors.danger.opacity(0.35)
        case .high:   return Color.appOrange.opacity(0.35)
        case .normal: return SierraTheme.Colors.info.opacity(0.35)
        case .low:    return Color.appTextSecondary.opacity(0.35)
        }
    }

    var icon: String {
        switch self {
        case .urgent: return "flame.fill"
        case .high:   return "exclamationmark.triangle.fill"
        case .normal: return "arrow.right.circle.fill"
        case .low:    return "minus.circle.fill"
        }
    }
}
