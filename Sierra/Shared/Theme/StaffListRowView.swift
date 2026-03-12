import SwiftUI

// MARK: - StaffListRowView

/// List row for staff members — used inside `List` or `ScrollView`.
/// No shadow (the parent list provides visual separation).
///
///     StaffListRowView(
///         initials: "JT",
///         fullName: "James Turner",
///         roleSubtitle: "Driver · +91 98765 43210",
///         status: DriverStatus.available,
///         metaLabel: "142 trips",
///         gradientColors: SierraAvatarView.driver()
///     )
struct StaffListRowView: View {

    let initials: String
    let fullName: String
    let roleSubtitle: String
    let status: any SierraStatus
    var metaLabel: String? = nil
    var gradientColors: [Color] = SierraAvatarView.driver()

    var body: some View {
        HStack(spacing: Spacing.md) {

            // ── Avatar ──
            SierraAvatarView(
                initials: initials,
                size: 40,
                gradient: gradientColors
            )

            // ── Text stack ──
            VStack(alignment: .leading, spacing: 2) {
                Text(fullName)
                    .sierraStyle(.cardTitle)
                Text(roleSubtitle)
                    .sierraStyle(.caption)
            }

            Spacer()

            // ── Status + meta ──
            VStack(alignment: .trailing, spacing: 4) {
                SierraBadge(status, size: .compact)
                if let metaLabel {
                    Text(metaLabel)
                        .font(SierraFont.monoXS)
                        .foregroundStyle(SierraTheme.Colors.granite)
                }
            }
        }
        .padding(Spacing.md)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}
