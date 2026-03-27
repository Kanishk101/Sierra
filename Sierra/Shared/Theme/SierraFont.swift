import SwiftUI
import UIKit

// MARK: - SierraFont

/// Complete typography scale for the Sierra Fleet Management System.
///
/// - **Display** - SF Pro Display: screen titles, hero numbers, modal headers
/// - **Body**    - SF Pro Text: body copy, labels, descriptions
/// - **Mono**    - SF Mono: VIN, license plates, task IDs, OTP codes, odometers
///
/// Usage: `.font(SierraFont.title1)` or `.font(SierraFont.display(28, weight: .bold))`
public enum SierraFont {

    // MARK: - Scaling Helpers

    private static func uiWeight(_ weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }

    private static func textStyle(for size: CGFloat) -> UIFont.TextStyle {
        switch size {
        case 34...: return .largeTitle
        case 28..<34: return .title1
        case 22..<28: return .title2
        case 20..<22: return .title3
        case 17..<20: return .headline
        case 15..<17: return .body
        case 13..<15: return .subheadline
        case 12..<13: return .footnote
        default: return .caption1
        }
    }

    private static func scaledFont(
        size: CGFloat,
        weight: Font.Weight,
        design: UIFontDescriptor.SystemDesign = .default
    ) -> Font {
        let base = UIFont.systemFont(ofSize: size, weight: uiWeight(weight))
        let descriptor = base.fontDescriptor.withDesign(design) ?? base.fontDescriptor
        let designed = UIFont(descriptor: descriptor, size: size)
        let scaled = UIFontMetrics(forTextStyle: textStyle(for: size)).scaledFont(for: designed)
        return Font(scaled)
    }

    private static func descriptorDesign(_ design: Font.Design) -> UIFontDescriptor.SystemDesign {
        switch design {
        case .default: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        case .monospaced: return .monospaced
        @unknown default: return .default
        }
    }

    /// Dynamic-type aware replacement for fixed-size `.system(size:)` fonts.
    static func scaled(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        scaledFont(size: size, weight: weight, design: descriptorDesign(design))
    }

    // ─────────────────────────────────────────
    // MARK: - Display Scale (SF Pro Display)
    // ─────────────────────────────────────────

    /// Dynamic display font - large, bold, headers.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        scaledFont(size: size, weight: weight, design: .default)
    }

    /// Screen titles - NavigationBar large title (34pt bold)
    static let largeTitle  = display(34, weight: .bold)
    /// Section headers, modal titles (28pt bold)
    static let title1      = display(28, weight: .bold)
    /// Card headers (22pt semibold)
    static let title2      = display(22, weight: .semibold)
    /// Sub-section titles (20pt semibold)
    static let title3      = display(20, weight: .semibold)

    // ─────────────────────────────────────────
    // MARK: - Body Scale (SF Pro Text)
    // ─────────────────────────────────────────

    /// Dynamic body font - standard text.
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        scaledFont(size: size, weight: weight, design: .default)
    }

    /// List row primary titles (17pt semibold)
    static let headline    = body(17, weight: .semibold)
    /// Body copy, descriptions (15pt regular)
    static let bodyText    = body(15, weight: .regular)
    /// Callout emphasis (16pt regular)
    static let callout     = body(16, weight: .regular)
    /// Secondary labels (15pt medium)
    static let subheadline = body(15, weight: .medium)
    /// Footnotes, metadata (13pt regular)
    static let footnote    = body(13, weight: .regular)
    /// Captions, timestamps, sub-labels (12pt medium)
    static let caption1    = body(12, weight: .medium)
    /// Pill badge labels, section labels, eyebrow text (11pt semibold)
    static let caption2    = body(11, weight: .semibold)

    // ─────────────────────────────────────────
    // MARK: - Monospaced Scale (SF Mono)
    // ─────────────────────────────────────────

    /// Dynamic mono font - data identifiers.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        scaledFont(size: size, weight: weight, design: .monospaced)
    }

    /// OTP / large data display (20pt medium)
    static let monoLG = mono(20, weight: .medium)
    /// VIN numbers (16pt regular)
    static let monoMD = mono(16, weight: .regular)
    /// License plates, task IDs inline (13pt medium)
    static let monoSM = mono(13, weight: .medium)
    /// Timestamps, metadata in list rows (11pt medium)
    static let monoXS = mono(11, weight: .medium)
}
