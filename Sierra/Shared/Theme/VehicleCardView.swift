import SwiftUI

// MARK: - VehicleCardView

/// Card displaying a single vehicle's summary — used in vehicle lists and dashboard.
///
///     VehicleCardView(
///         vehicleName: "Hauler Alpha",
///         makeModel: "Volvo FH16 · 2024",
///         licensePlate: "FL · 1024",
///         status: .active,
///         fuelType: "Diesel",
///         odometer: "45,230 km",
///         expiryWarning: nil
///     )
struct VehicleCardView: View {

    let vehicleName: String
    let makeModel: String
    let licensePlate: String
    let status: VehicleStatus
    var fuelType: String? = nil
    var odometer: String? = nil
    var expiryWarning: String? = nil

    var body: some View {
        SierraCard(borderAccentColor: status.accentBorderColor) {
            VStack(alignment: .leading, spacing: Spacing.xs) {

                // ── Header row ──
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vehicleName)
                            .sierraStyle(.cardTitle)
                        Text(makeModel)
                            .sierraStyle(.caption)
                    }
                    Spacer()
                    SierraBadge(status, size: .compact)
                }

                // ── License plate ──
                Text(licensePlate)
                    .licensePlate()

                // ── Meta row ──
                if fuelType != nil || odometer != nil {
                    HStack(spacing: Spacing.xs) {
                        if let fuelType {
                            metaLabel(fuelType)
                        }
                        if fuelType != nil && odometer != nil {
                            metaDot
                        }
                        if let odometer {
                            metaLabel(odometer)
                        }
                    }
                }

                // ── Expiry warning ──
                if let expiryWarning {
                    Text(expiryWarning)
                        .font(SierraFont.caption1)
                        .foregroundStyle(SierraTheme.Colors.warning)
                }
            }
        }
    }

    // MARK: - Helpers

    private func metaLabel(_ text: String) -> some View {
        Text(text)
            .font(SierraFont.caption1)
            .foregroundStyle(SierraTheme.Colors.granite)
    }

    private var metaDot: some View {
        Text("·")
            .font(SierraFont.caption1)
            .foregroundStyle(SierraTheme.Colors.granite)
    }
}
