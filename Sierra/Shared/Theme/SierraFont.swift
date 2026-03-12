import SwiftUI

// MARK: - SierraFont

/// Complete typography scale for the Sierra Fleet Management System.
///
/// - **Display** — SF Pro Display: screen titles, hero numbers, modal headers
/// - **Body**    — SF Pro Text: body copy, labels, descriptions
/// - **Mono**    — SF Mono: VIN, license plates, task IDs, OTP codes, odometers
///
/// Usage: `.font(SierraFont.title1)` or `.font(SierraFont.display(28, weight: .bold))`
public enum SierraFont {

    // ─────────────────────────────────────────
    // MARK: - Display Scale (SF Pro Display)
    // ─────────────────────────────────────────

    /// Dynamic display font — large, bold, headers.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Screen titles — NavigationBar large title (34pt bold)
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

    /// Dynamic body font — standard text.
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
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

    /// Dynamic mono font — data identifiers.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
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
