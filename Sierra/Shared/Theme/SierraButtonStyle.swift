import SwiftUI

// MARK: - Shared Button Typography

/// Common font + kerning applied to all Sierra button labels.
private let buttonFont = SierraFont.body(15, weight: .semibold)
private let buttonKerning: CGFloat = -0.15

// ─────────────────────────────────────────
// MARK: - Primary (Ember fill, white text)
// ─────────────────────────────────────────

struct SierraPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(buttonFont)
            .kerning(buttonKerning)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(
                SierraTheme.Colors.ember,
                in: Capsule(style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

// ─────────────────────────────────────────
// MARK: - Secondary (SummitNavy fill, white text)
// ─────────────────────────────────────────

struct SierraSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(buttonFont)
            .kerning(buttonKerning)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(
                SierraTheme.Colors.summitNavy,
                in: Capsule(style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

// ─────────────────────────────────────────
// MARK: - Ghost (Ember tint bg, ember dark text)
// ─────────────────────────────────────────

struct SierraGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(buttonFont)
            .kerning(buttonKerning)
            .foregroundStyle(SierraTheme.Colors.emberDark)
            .frame(minHeight: 44)
            .padding(.horizontal, Spacing.lg)
            .background(
                SierraTheme.Colors.ember.opacity(configuration.isPressed ? 0.16 : 0.10),
                in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .strokeBorder(SierraTheme.Colors.ember.opacity(0.20), lineWidth: 1.5)
            )
    }
}

// ─────────────────────────────────────────
// MARK: - Outline (Clear bg, mist border)
// ─────────────────────────────────────────

struct SierraOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(buttonFont)
            .kerning(buttonKerning)
            .foregroundStyle(SierraTheme.Colors.summitNavy)
            .frame(minHeight: 44)
            .padding(.horizontal, Spacing.lg)
            .background(
                configuration.isPressed
                    ? SierraTheme.Colors.mist.opacity(0.15)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .strokeBorder(SierraTheme.Colors.mist, lineWidth: 1.5)
            )
    }
}

// ─────────────────────────────────────────
// MARK: - Danger (Red tint bg, red text)
// ─────────────────────────────────────────

struct SierraDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(buttonFont)
            .kerning(buttonKerning)
            .foregroundStyle(Color(hex: "DC2626"))
            .frame(minHeight: 44)
            .padding(.horizontal, Spacing.lg)
            .background(
                SierraTheme.Colors.danger.opacity(configuration.isPressed ? 0.18 : 0.10),
                in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .strokeBorder(SierraTheme.Colors.danger.opacity(0.20), lineWidth: 1.5)
            )
    }
}

// ─────────────────────────────────────────
// MARK: - Text Only (No bg, ember text)
// ─────────────────────────────────────────

struct SierraTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SierraFont.body(15, weight: .semibold))
            .kerning(buttonKerning)
            .foregroundStyle(SierraTheme.Colors.ember)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
