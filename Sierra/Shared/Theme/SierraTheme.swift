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
        /// #F07B35 - ALL primary CTAs, active states, progress, FAB, links
        public static let ember        = Color("Ember")
        /// #F9A872 - ember tint on dark backgrounds
        public static let emberLight   = Color("EmberLight")
        /// #C45E1A - pressed states, destructive ember contexts
        public static let emberDark    = Color("EmberDark")
        /// #0AB891 - success, available driver, completed, checkmarks
        public static let alpineMint   = Color("AlpineMint")
        /// #4DCFB3 - mint tint on dark bg
        public static let alpineLight  = Color("AlpineLight")
        /// #078A6C - mint pressed / dark mode text
        public static let alpineDark   = Color("AlpineDark")

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
        public static let success      = Color("AlpineMint")
        /// #F59E0B - expiring docs, pending approval, in-maintenance
        public static let warning      = Color("Warning")
        /// #EF4444 - destructive buttons, expired docs, cancelled, failed inspection
        public static let danger       = Color("Danger")
        /// #3B82F6 - informational states, scheduled/pending trip
        public static let info         = Color("Info")

        // ── Adaptive (Light / Dark) ──

        /// light: Snowfield (#F4F7FB), dark: Obsidian (#0A0F1E)
        public static let appBackground  = Color("AppBackground")
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
        public static let lg:     CGFloat = 14
        public static let xl:     CGFloat = 16
        public static let xxl:    CGFloat = 20
        public static let card:   CGFloat = 16
        public static let badge:  CGFloat = 20
        public static let button: CGFloat = 14
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
    static let statusActive    = SierraTheme.Colors.alpineMint
    /// Vehicle idle, paused
    static let statusIdle      = Color.gray
    /// Trip scheduled, awaiting
    static let statusScheduled = SierraTheme.Colors.info
    /// Expiring docs, pending review, in-maintenance
    static let statusWarning   = SierraTheme.Colors.warning
    /// Cancelled, expired, emergency, breakdown
    static let statusDanger    = SierraTheme.Colors.danger
    /// Trip completed, resolved
    static let statusCompleted = Color.secondary

    // ── Driver UI Design Tokens (FMS_SS reference) ──

    /// Primary brand orange — CTAs, accents, active states
    static let appOrange      = Color(red: 0.95, green: 0.55, blue: 0.10)
    /// Warm amber — gradient endpoints, slider knob start
    static let appAmber       = Color(red: 1.0, green: 0.75, blue: 0.20)
    /// Deep orange — gradient dark end, pressed states
    static let appDeepOrange  = Color(red: 0.90, green: 0.35, blue: 0.08)
    /// Light neutral surface — screen backgrounds
    static let appSurface     = Color(red: 0.97, green: 0.97, blue: 0.96)
    /// Card background (white)
    static let appCardBg      = Color.white
    /// Primary text — near-black
    static let appTextPrimary = Color(red: 0.12, green: 0.12, blue: 0.14)
    /// Secondary text — gray captions
    static let appTextSecondary = Color(red: 0.45, green: 0.45, blue: 0.48)
    /// Divider / separator lines
    static let appDivider     = Color(red: 0.92, green: 0.92, blue: 0.93)
}

// MARK: - TripPriority UI Helpers

extension TripPriority {
    var color: Color {
        switch self {
        case .urgent: return Color(red: 0.85, green: 0.18, blue: 0.15)
        case .high:   return Color.appOrange
        case .normal: return Color(red: 0.20, green: 0.50, blue: 0.90)
        case .low:    return Color.appTextSecondary
        }
    }

    var bgColor: Color {
        switch self {
        case .urgent: return Color(red: 0.85, green: 0.18, blue: 0.15).opacity(0.10)
        case .high:   return Color.appOrange.opacity(0.10)
        case .normal: return Color(red: 0.20, green: 0.50, blue: 0.90).opacity(0.10)
        case .low:    return Color.appTextSecondary.opacity(0.10)
        }
    }

    var borderColor: Color {
        switch self {
        case .urgent: return Color(red: 0.85, green: 0.18, blue: 0.15).opacity(0.35)
        case .high:   return Color.appOrange.opacity(0.35)
        case .normal: return Color(red: 0.20, green: 0.50, blue: 0.90).opacity(0.35)
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
