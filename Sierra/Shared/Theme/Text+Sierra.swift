import SwiftUI

// MARK: - Text + Sierra Convenience Wrappers

extension Text {

    // MARK: - Eyebrow Label

    /// Uppercase section divider — applies `.eyebrow` style with uppercased transform.
    ///
    ///     Text("vehicle details").eyebrow()
    func eyebrow() -> some View {
        self
            .textCase(.uppercase)
            .sierraStyle(.eyebrow)
    }

    // MARK: - Mono Data Display

    /// Monospaced data display — SF Mono, summitNavy adaptive, with tracking.
    /// Used for VIN numbers, license plates, task IDs, odometer readings.
    ///
    ///     Text("YV2A4C2A8RB123456").monoData()
    ///     Text("45,230.5 km").monoData(16)
    func monoData(_ size: CGFloat = 13) -> some View {
        self
            .font(SierraFont.mono(size, weight: .medium))
            .foregroundStyle(SierraTheme.Colors.primaryText)
            .tracking(0.5)
    }

    // MARK: - License Plate Display

    /// License plate pill — mono font, ember-tinted background capsule.
    ///
    ///     Text("FL · 1024").licensePlate()
    func licensePlate() -> some View {
        self
            .font(SierraFont.monoSM)
            .foregroundStyle(SierraTheme.Colors.primaryText)
            .tracking(0.5)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(
                SierraTheme.Colors.ember.opacity(0.10),
                in: Capsule()
            )
    }
}
