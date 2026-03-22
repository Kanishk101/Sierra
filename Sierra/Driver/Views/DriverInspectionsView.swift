import SwiftUI

/// Phase 12: New Driver tab — shows list of pre/post trip inspections performed by this driver.
struct DriverInspectionsView: View {

    @Environment(AppDataStore.self) private var store

    private var driverInspections: [VehicleInspection] {
        guard let driverId = AuthManager.shared.currentUser?.id else { return [] }
        return store.vehicleInspections
            .filter { $0.driverId == driverId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        Group {
            if driverInspections.isEmpty {
                SierraEmptyState(
                    icon: "checklist",
                    title: "No Inspections",
                    message: "Your vehicle inspections will appear here."
                )
            } else {
                List(driverInspections) { inspection in
                    inspectionRow(inspection)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Inspections")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Row

    private func inspectionRow(_ inspection: VehicleInspection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(inspection.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                      systemImage: inspection.type == .preTripInspection
                        ? "arrow.right.circle.fill"
                        : "arrow.left.circle.fill")
                    .font(.subheadline.weight(.medium))
                Spacer()
                resultBadge(inspection.overallResult)
            }

            HStack(spacing: 12) {
                Text(inspection.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let vehicleName = vehicleName(for: inspection.vehicleId) {
                    Text(vehicleName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func resultBadge(_ result: InspectionResult) -> some View {
        Text(result.rawValue.capitalized)
            .font(.caption2.weight(.bold))
            .foregroundStyle(resultColor(result))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(resultColor(result).opacity(0.12), in: Capsule())
    }

    private func resultColor(_ result: InspectionResult) -> Color {
        switch result {
        case .passed:             return SierraTheme.Colors.alpineMint
        case .passedWithWarnings: return SierraTheme.Colors.warning
        case .failed:             return SierraTheme.Colors.danger
        case .notChecked:         return .gray
        }
    }

    private func vehicleName(for vehicleId: UUID) -> String? {
        guard let vehicle = store.vehicle(for: vehicleId) else { return nil }
        return "\(vehicle.name) \(vehicle.model)"
    }
}
