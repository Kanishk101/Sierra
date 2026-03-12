import SwiftUI

// MARK: - Sierra Text Style Tokens

/// Named text style tokens that pair font, color, and tracking.
/// Every `Text()` in the app should use `.sierraStyle(.token)` instead
/// of raw `.font()` / `.foregroundColor()` calls.
public enum SierraTextStyleToken {
    /// Large title — 34pt bold, summitNavy/white adaptive, tight tracking
    case screenTitle
    /// Section header — 22pt semibold, summitNavy adaptive
    case sectionHeader
    /// Card title — 17pt semibold, summitNavy adaptive
    case cardTitle
    /// Body copy — 15pt regular, slate adaptive
    case primaryBody
    /// Secondary text — 15pt medium, granite
    case secondaryBody
    /// Captions, timestamps — 12pt medium, granite
    case caption
    /// Uppercase section dividers — 11pt semibold, granite, wide tracking
    case eyebrow
    /// SF Mono data — 13pt medium, summitNavy adaptive (VINs, plates, IDs)
    case monoData
    /// SF Mono hero numeric — 20pt medium, ember (OTP, large data)
    case monoDataLarge
    /// Badge labels — 11pt semibold, tracking 0.3 (color set per badge variant)
    case badgeLabel
    /// Destructive text — 15pt medium, danger red
    case destructive
    /// Link / tappable text — 15pt medium, ember
    case link
}

// MARK: - SierraTextStyleModifier

/// ViewModifier that applies the correct Font + foregroundStyle + tracking
/// for a given `SierraTextStyleToken`.
struct SierraTextStyleModifier: ViewModifier {

    let style: SierraTextStyleToken

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundStyle(color)
            .tracking(tracking)
    }

    // MARK: - Font Mapping

    private var font: Font {
        switch style {
        case .screenTitle:    SierraFont.largeTitle
        case .sectionHeader:  SierraFont.title2
        case .cardTitle:      SierraFont.headline
        case .primaryBody:    SierraFont.bodyText
        case .secondaryBody:  SierraFont.subheadline
        case .caption:        SierraFont.caption1
        case .eyebrow:        SierraFont.caption2
        case .monoData:       SierraFont.monoSM
        case .monoDataLarge:  SierraFont.monoLG
        case .badgeLabel:     SierraFont.caption2
        case .destructive:    SierraFont.subheadline
        case .link:           SierraFont.subheadline
        }
    }

    // MARK: - Color Mapping

    private var color: Color {
        switch style {
        case .screenTitle:    SierraTheme.Colors.primaryText
        case .sectionHeader:  SierraTheme.Colors.primaryText
        case .cardTitle:      SierraTheme.Colors.primaryText
        case .primaryBody:    SierraTheme.Colors.slate
        case .secondaryBody:  SierraTheme.Colors.granite
        case .caption:        SierraTheme.Colors.granite
        case .eyebrow:        SierraTheme.Colors.granite
        case .monoData:       SierraTheme.Colors.primaryText
        case .monoDataLarge:  SierraTheme.Colors.ember
        case .badgeLabel:     SierraTheme.Colors.primaryText // overridden per badge
        case .destructive:    SierraTheme.Colors.danger
        case .link:           SierraTheme.Colors.ember
        }
    }

    // MARK: - Tracking Mapping

    private var tracking: CGFloat {
        switch style {
        case .screenTitle:    -0.6   // tight display
        case .sectionHeader:  -0.3
        case .eyebrow:         1.5   // wide uppercase
        case .monoData:        0.5   // mono identifiers
        case .monoDataLarge:   0.5
        case .badgeLabel:      0.3   // subtle badge
        default:               0
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies a Sierra text style token (font + color + tracking).
    func sierraStyle(_ style: SierraTextStyleToken) -> some View {
        modifier(SierraTextStyleModifier(style: style))
    }
}

// MARK: - Text Extension

extension Text {
    /// Applies a Sierra text style token to a Text view.
    func sierraStyle(_ style: SierraTextStyleToken) -> some View {
        modifier(SierraTextStyleModifier(style: style))
    }
}
