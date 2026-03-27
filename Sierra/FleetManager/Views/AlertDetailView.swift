import SwiftUI
import MapKit

/// Full detail view for an emergency alert.
/// Safeguard 6: tel:// is the ONLY permitted UIApplication.shared.open().
struct AlertDetailView: View {

    let alert: EmergencyAlert
    var onUpdate: () -> Void
    var onOpenMaintenanceTask: ((UUID) -> Void)? = nil

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isOpeningMaintenance = false
    @State private var isDriverExpanded = true
    @State private var isVehicleExpanded = true
    @State private var errorMessage: String?
    @State private var showError = false

    private var currentAlert: EmergencyAlert {
        store.emergencyAlerts.first(where: { $0.id == alert.id }) ?? alert
    }

    private var driver: StaffMember? {
        store.staff.first(where: { $0.id == currentAlert.driverId })
    }

    private var vehicle: Vehicle? {
        guard let vId = currentAlert.vehicleId else { return nil }
        return store.vehicles.first(where: { $0.id == vId })
    }

    private var isPreTripDefectAlert: Bool {
        guard currentAlert.alertType == .defect, let tripId = currentAlert.tripId else { return false }
        guard let preInspection = store.preInspection(forTrip: tripId) else { return false }
        return preInspection.overallResult == .failed
    }

    private var canReassignVehicle: Bool {
        guard isPreTripDefectAlert, let tripId = currentAlert.tripId else { return false }
        guard currentAlert.status == .active || currentAlert.status == .acknowledged else { return false }
        guard let trip = store.trip(for: tripId) else { return false }
        return store.isTripWaitingForVehicleReassignment(trip)
    }

    private var canOpenMaintenance: Bool {
        currentAlert.alertType == .defect || currentAlert.alertType == .breakdown
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
            .toolbarBackground(.hidden, for: .navigationBar)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
    }

    // MARK: - Map

    private var mapSection: some View {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: currentAlert.latitude, longitude: currentAlert.longitude),
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        )
        return Map(initialPosition: .region(region)) {
            Annotation("Alert", coordinate: CLLocationCoordinate2D(latitude: currentAlert.latitude, longitude: currentAlert.longitude)) {
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
                Text(currentAlert.alertType.rawValue)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.red)
                Spacer()
                Text(currentAlert.status.rawValue)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(currentAlert.status == .active ? .red : (currentAlert.status == .acknowledged ? .orange : .green), in: Capsule())
            }

            if let desc = currentAlert.description, !desc.isEmpty {
                Text(desc).font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Label(currentAlert.triggeredAt.formatted(.dateTime.hour().minute().second()), systemImage: "clock")
                Label("\(currentAlert.latitude, specifier: "%.4f"), \(currentAlert.longitude, specifier: "%.4f")", systemImage: "mappin")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Driver Card

    private func driverCard(_ d: StaffMember) -> some View {
        DisclosureGroup(isExpanded: $isDriverExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                infoLine("Name", d.displayName)
                infoLine("Role", d.role.rawValue)
                infoLine("Status", d.status.rawValue)
                infoLine("Availability", d.availability.rawValue)
                if !d.email.isEmpty { infoLine("Email", d.email) }
                if let phone = d.phone, !phone.isEmpty {
                    HStack {
                        infoLine("Phone", phone)
                        Spacer()
                        // Safeguard 6: tel:// is the only permitted open()
                        Button {
                            let digits = phone.filter { $0.isNumber }
                            if let url = URL(string: "tel://\(digits)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Image(systemName: "phone.fill")
                                .foregroundStyle(.green)
                                .frame(width: 34, height: 34)
                                .background(.green.opacity(0.1), in: Circle())
                        }
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(SierraTheme.Colors.info)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Driver Details")
                        .font(.subheadline.weight(.semibold))
                    Text(d.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Vehicle Card

    private func vehicleCard(_ v: Vehicle) -> some View {
        DisclosureGroup(isExpanded: $isVehicleExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                infoLine("Name", v.name)
                infoLine("Plate", v.licensePlate)
                infoLine("Model", v.model)
                infoLine("Manufacturer", v.manufacturer)
                infoLine("Status", v.status.rawValue)
                infoLine("Fuel Type", v.fuelType.rawValue)
                infoLine("Odometer", "\(Int(v.odometer)) km")
                infoLine("Total Trips", "\(v.totalTrips)")
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "car.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vehicle Details")
                        .font(.subheadline.weight(.semibold))
                    Text("\(v.licensePlate) • \(v.model)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 12) {
            if canReassignVehicle {
                Button {
                    routeToStaffMaintenance()
                } label: {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver")
                        Text("Go to maintenance")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(SierraTheme.Colors.info, in: RoundedRectangle(cornerRadius: 12))
                }
            } else if canOpenMaintenance {
                Button {
                    Task { await openLinkedMaintenanceTask() }
                } label: {
                    HStack {
                        if isOpeningMaintenance {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "wrench.and.screwdriver")
                            Text("Open Maintenance Task")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(SierraTheme.Colors.info, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isOpeningMaintenance)
            }
        }
    }

    private func openLinkedMaintenanceTask() async {
        guard !isOpeningMaintenance else { return }
        isOpeningMaintenance = true
        defer { isOpeningMaintenance = false }

        do {
            if let local = store.maintenanceTasks.first(where: { $0.sourceAlertId == currentAlert.id }) {
                routeToMaintenance(taskId: local.id)
                return
            }

            if let remote = try await MaintenanceTaskService.fetchTask(sourceAlertId: currentAlert.id) {
                routeToMaintenance(taskId: remote.id)
                return
            }

            errorMessage = "No linked maintenance task found for this alert yet."
            showError = true
        } catch {
            errorMessage = "Failed to open maintenance task: \(error.localizedDescription)"
            showError = true
        }
    }

    private func routeToMaintenance(taskId: UUID) {
        if let onOpenMaintenanceTask {
            onOpenMaintenanceTask(taskId)
        } else {
            NotificationCenter.default.post(
                name: .sierraOpenVehicleMaintenance,
                object: nil,
                userInfo: ["taskId": taskId.uuidString]
            )
            dismiss()
        }
    }

    private func routeToStaffMaintenance() {
        NotificationCenter.default.post(name: .sierraOpenStaffMaintenance, object: nil)
        dismiss()
    }

    private func infoLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
    }
}

extension Notification.Name {
    static let sierraOpenVehicleMaintenance = Notification.Name("sierraOpenVehicleMaintenance")
    static let sierraOpenStaffMaintenance = Notification.Name("sierraOpenStaffMaintenance")
}
