import SwiftUI
import MapKit

/// Full detail view for an emergency alert.
/// Safeguard 6: tel:// is the ONLY permitted UIApplication.shared.open().
struct AlertDetailView: View {

    let alert: EmergencyAlert
    var onUpdate: () -> Void

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isAcknowledging = false
    @State private var isResolving = false
    @State private var showReassignment = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    private var driver: StaffMember? {
        store.staff.first(where: { $0.id == alert.driverId })
    }

    private var vehicle: Vehicle? {
        guard let vId = alert.vehicleId else { return nil }
        return store.vehicles.first(where: { $0.id == vId })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Map
                mapSection

                // Alert info
                alertInfo

                // Driver card
                if let d = driver {
                    driverCard(d)
                }

                // Vehicle card
                if let v = vehicle {
                    vehicleCard(v)
                }

                Divider()

                // Actions
                actions
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Alert Detail")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
        .sheet(isPresented: $showReassignment) {
            if let tripId = alert.tripId {
                VehicleReassignmentSheet(tripId: tripId)
            }
        }
    }

    // MARK: - Map

    private var mapSection: some View {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: alert.latitude, longitude: alert.longitude),
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        )
        return Map(initialPosition: .region(region)) {
            Annotation("Alert", coordinate: CLLocationCoordinate2D(latitude: alert.latitude, longitude: alert.longitude)) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .padding(6)
                    .background(.white, in: Circle())
                    .shadow(radius: 3)
            }
        }
        .mapStyle(.standard)
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Alert Info

    private var alertInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sos.circle.fill")
                    .foregroundStyle(.red)
                Text(alert.alertType.rawValue)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.red)
                Spacer()
                Text(alert.status.rawValue)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(alert.status == .active ? .red : (alert.status == .acknowledged ? .orange : .green), in: Capsule())
            }

            if let desc = alert.description, !desc.isEmpty {
                Text(desc).font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Label(alert.triggeredAt.formatted(.dateTime.hour().minute().second()), systemImage: "clock")
                Label("\(alert.latitude, specifier: "%.4f"), \(alert.longitude, specifier: "%.4f")", systemImage: "mappin")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Driver Card

    private func driverCard(_ d: StaffMember) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title2).foregroundStyle(SierraTheme.Colors.info)
            VStack(alignment: .leading, spacing: 2) {
                Text(d.name ?? "Unknown").font(.subheadline.weight(.medium))
                Text(d.phone ?? "No phone").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            // Safeguard 6: tel:// is the only permitted open()
            if let phone = d.phone {
                Button {
                    let digits = phone.filter { $0.isNumber }
                    if let url = URL(string: "tel://\(digits)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Image(systemName: "phone.fill")
                        .foregroundStyle(.green)
                        .frame(width: 36, height: 36)
                        .background(.green.opacity(0.1), in: Circle())
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Vehicle Card

    private func vehicleCard(_ v: Vehicle) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "car.fill")
                .font(.title2).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(v.name).font(.subheadline.weight(.medium))
                Text("\(v.licensePlate) • \(v.model)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 12) {
            if alert.status == .active {
                Button {
                    Task { await acknowledge() }
                } label: {
                    HStack {
                        if isAcknowledging { ProgressView().tint(.white) }
                        Text("Acknowledge")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(.orange, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isAcknowledging)
            }

            if alert.status == .active || alert.status == .acknowledged {
                Button {
                    Task { await resolve() }
                } label: {
                    HStack {
                        if isResolving { ProgressView().tint(.white) }
                        Text("Resolve")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(.green, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isResolving)
            }

            // Create Maintenance for Breakdown/Defect
            if alert.alertType == .breakdown || alert.alertType == .defect {
                NavigationLink {
                    Text("Create maintenance task from alert")  // Placeholder — already handled by FM workflow
                } label: {
                    Text("Create Maintenance Task")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(SierraTheme.Colors.info)
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(SierraTheme.Colors.info.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            // Vehicle reassignment for inspection failures
            if alert.alertType == .defect, alert.tripId != nil {
                Button {
                    showReassignment = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Reassign Vehicle")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(SierraTheme.Colors.ember, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Acknowledge

    private func acknowledge() async {
        isAcknowledging = true
        do {
            try await EmergencyAlertService.acknowledgeAlert(id: alert.id, acknowledgedBy: currentUserId)

            // Notify driver (non-fatal)
            do {
                try await NotificationService.insertNotification(
                    recipientId: alert.driverId,
                    type: .general,
                    title: "Alert Acknowledged",
                    body: "Your \(alert.alertType.rawValue) alert has been received. Help is on the way.",
                    entityType: "emergency_alert",
                    entityId: alert.id
                )
            } catch {
                print("[AlertDetail] Non-fatal: notification to driver failed")
            }

            onUpdate()
            dismiss()
        } catch {
            errorMessage = "Failed: \(error.localizedDescription)"
            showError = true
        }
        isAcknowledging = false
    }

    // MARK: - Resolve

    private func resolve() async {
        isResolving = true
        do {
            try await EmergencyAlertService.resolveAlert(id: alert.id)
            onUpdate()
            dismiss()
        } catch {
            errorMessage = "Failed: \(error.localizedDescription)"
            showError = true
        }
        isResolving = false
    }
}
