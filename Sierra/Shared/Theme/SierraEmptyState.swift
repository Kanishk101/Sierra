import SwiftUI

// MARK: - SierraEmptyState

/// Centered empty state placeholder for lists, grids, and detail screens.
///
///     SierraEmptyState(icon: "truck.box", title: "No Vehicles",
///                      message: "Add your first vehicle to get started.",
///                      actionTitle: "Add Vehicle") { showAddVehicle = true }
struct SierraEmptyState: View {

    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            // ── Icon ──
            Image(systemName: icon)
                .font(SierraFont.scaled(32, weight: .medium))
                .foregroundStyle(SierraTheme.Colors.granite)
                .frame(width: 80, height: 80)
                .background(
                    SierraTheme.Colors.snowfield,
                    in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                )

            // ── Text ──
            VStack(spacing: Spacing.xxs) {
                Text(title)
                    .sierraStyle(.sectionHeader)
                Text(message)
                    .sierraStyle(.secondaryBody)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxl)
            }

            // ── Optional CTA ──
            if let actionTitle, let action {
                SierraButton.primary(actionTitle, action: action)
                    .padding(.horizontal, Spacing.section)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
