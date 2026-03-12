import SwiftUI

// MARK: - StatCardView

/// Dashboard stat card — displays a label and numeric value with accent tinting.
/// Used in the Fleet Manager dashboard 4-column grid.
///
///     StatCardView.vehicles(count: 5)
///     StatCardView.active(count: 2)
struct StatCardView: View {

    let label: String
    let value: String
    let accentColor: Color
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(accentColor)
                }
                Text(label)
                    .textCase(.uppercase)
                    .font(SierraFont.caption2)
                    .foregroundStyle(SierraTheme.Colors.granite)
                    .tracking(1.2)
                Spacer()
            }

            Text(value)
                .font(SierraFont.title1)
                .foregroundStyle(accentColor)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(SierraTheme.Colors.cloud, lineWidth: 1)
        )
        .sierraShadow(SierraTheme.Shadow.card)
    }

    // MARK: - Presets

    /// Total vehicles
    static func vehicles(count: Int) -> StatCardView {
        StatCardView(
            label: "Vehicles",
            value: "\(count)",
            accentColor: SierraTheme.Colors.sierraBlue,
            icon: "car.fill"
        )
    }

    /// Active trips/vehicles
    static func active(count: Int) -> StatCardView {
        StatCardView(
            label: "Active",
            value: "\(count)",
            accentColor: SierraTheme.Colors.alpineMint,
            icon: "location.fill"
        )
    }

    /// Available drivers
    static func available(count: Int) -> StatCardView {
        StatCardView(
            label: "Available",
            value: "\(count)",
            accentColor: SierraTheme.Colors.alpineMint,
            icon: "person.fill.checkmark"
        )
    }

    /// Pending approvals
    static func pending(count: Int) -> StatCardView {
        StatCardView(
            label: "Pending",
            value: "\(count)",
            accentColor: SierraTheme.Colors.info,
            icon: "person.2.fill"
        )
    }
}
