import SwiftUI

/// Bottom sheet showing vehicle details when admin taps an annotation.
struct VehicleMapDetailSheet: View {

    let vehicle: Vehicle
    var onDismiss: () -> Void

    @Environment(AppDataStore.self) private var store
    @State private var isSendingAlert = false
    @State private var alertSent = false

    private var activeTrip: Trip? {
        store.trips.first { trip in
            trip.vehicleId == vehicle.id.uuidString && trip.status == .active
        }
    }

    private var assignedDriver: StaffMember? {
        guard let driverId = vehicle.assignedDriverId else { return nil }
        return store.staff.first { $0.id.uuidString == driverId }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    vehicleHeader
                    Divider()

                    if let trip = activeTrip {
                        activeTripSection(trip)
                    } else {
                        idleSection
                    }
                }
                .padding(16)
            }
            .navigationTitle("Vehicle Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Vehicle Header

    private var vehicleHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: "car.fill")
                .font(.title)
                .foregroundStyle(statusColor)
                .frame(width: 50, height: 50)
                .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(vehicle.name) \(vehicle.model)")
                    .font(.headline)
                Text(vehicle.licensePlate)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(vehicle.status.rawValue)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(statusColor)
                }
            }
            Spacer()
        }
    }

    // MARK: - Active Trip

    private func activeTripSection(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Trip info
            VStack(alignment: .leading, spacing: 8) {
                Text("ACTIVE TRIP")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .kerning(1)

                Text(trip.taskId)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(SierraTheme.Colors.ember)

                HStack(spacing: 8) {
                    Label(trip.origin, systemImage: "location.circle.fill")
                        .font(.caption)
                        .foregroundStyle(SierraTheme.Colors.alpineMint)
                    Text("\u{2192}")
                        .font(.caption)
                    Label(trip.destination, systemImage: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundStyle(SierraTheme.Colors.ember)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

            // Driver info
            if let driver = assignedDriver {
                HStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.title3)
                        .foregroundStyle(SierraTheme.Colors.info)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(driver.name ?? "Unknown")
                            .font(.subheadline.weight(.medium))
                        Text(driver.phone ?? "No phone")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                NavigationLink(value: trip.id) {
                    Text("View Full Trip")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(SierraTheme.Colors.info, in: RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    Task { await sendAlertToDriver() }
                } label: {
                    HStack(spacing: 4) {
                        if isSendingAlert {
                            ProgressView().tint(.white)
                        }
                        Text(alertSent ? "Sent ✓" : "Alert Driver")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(alertSent ? SierraTheme.Colors.alpineMint : SierraTheme.Colors.warning,
                                in: RoundedRectangle(cornerRadius: 10))
                }
                .disabled(isSendingAlert || alertSent)
            }

            // ETA
            if let endDate = trip.scheduledEndDate {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text("ETA: \(endDate.formatted(.dateTime.hour().minute()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Idle Section

    private var idleSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 32))
                .foregroundStyle(.gray.opacity(0.5))
            Text("Vehicle is idle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch vehicle.status {
        case .active, .busy: return SierraTheme.Colors.info
        case .idle: return .gray
        case .inMaintenance: return .orange
        case .outOfService, .decommissioned: return SierraTheme.Colors.danger
        }
    }

    private func sendAlertToDriver() async {
        guard let driverId = vehicle.assignedDriverUUID else { return }
        isSendingAlert = true
        do {
            try await NotificationService.insertNotification(
                recipientId: driverId,
                type: .general,
                title: "Fleet Alert",
                body: "Fleet manager is requesting your attention for vehicle \(vehicle.licensePlate).",
                entityType: "vehicle",
                entityId: vehicle.id
            )
            alertSent = true
        } catch {
            print("[VehicleDetailSheet] Alert send failed: \(error)")
        }
        isSendingAlert = false
    }
}
