import SwiftUI

// MARK: - SierraAvatarView

/// Reusable staff avatar displaying initials over a gradient.
///
///     SierraAvatarView(initials: "JT")
///     SierraAvatarView(initials: "SM", size: 32, gradient: SierraAvatarView.maintenance())
struct SierraAvatarView: View {

    let initials: String
    var size: CGFloat = 40
    var gradient: [Color] = SierraAvatarView.driver()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(initials)
                .font(SierraFont.caption1)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: Radius.avatar, style: .continuous))
    }

    // MARK: - Role Gradient Presets

    /// Driver avatar gradient: sierraBlue → summitNavy
    static func driver() -> [Color] {
        [SierraTheme.Colors.sierraBlue, SierraTheme.Colors.summitNavy]
    }

    /// Admin / Fleet Manager avatar gradient: ember → emberDark
    static func admin() -> [Color] {
        [SierraTheme.Colors.ember, SierraTheme.Colors.emberDark]
    }

    /// Maintenance personnel avatar gradient: info blue → indigo
    static func maintenance() -> [Color] {
        [SierraTheme.Colors.info, Color(hex: "1D4ED8")]
    }
}

// MARK: - Preview

#Preview("Avatars") {
    HStack(spacing: 16) {
        SierraAvatarView(initials: "JT")
        SierraAvatarView(initials: "AM", size: 48, gradient: SierraAvatarView.admin())
        SierraAvatarView(initials: "SK", size: 36, gradient: SierraAvatarView.maintenance())
    }
    .padding()
}
