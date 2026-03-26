import SwiftUI

/// Sheet for the Fleet Manager to reassign a vehicle to a trip after pre-trip inspection failure.
/// Shows only available vehicles (Active or Idle status). Does NOT manually update vehicle status
/// — the DB trigger handles that when the trip eventually starts.
struct VehicleReassignmentSheet: View {

    let tripId: UUID
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedVehicleId: UUID? = nil
    @State private var isSubmitting = false
    @State private var errorText: String? = nil
    @State private var searchText = ""

    /// Only vehicles that are currently assignable (Active or Idle).
    private var availableVehicles: [Vehicle] {
        let base = store.vehicles.filter { v in
            v.status == .active || v.status == .idle
        }
        guard !searchText.isEmpty else { return base }
        let query = searchText.lowercased()
        return base.filter { vehicle in
            let nameMatch = vehicle.name.lowercased().contains(query)
            let plateMatch = vehicle.licensePlate.lowercased().contains(query)
            let modelMatch = vehicle.model.lowercased().contains(query)
            return nameMatch || plateMatch || modelMatch
        }
    }

    var body: some View {
        NavigationStack {
            vehicleList
                .searchable(text: $searchText, prompt: "Search vehicles")
                .navigationTitle("Reassign Vehicle")
                .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar { toolbarContent }
                .overlay { emptyOverlay }
                .alert("Error", isPresented: .constant(errorText != nil)) {
                    Button("OK") { errorText = nil }
                } message: {
                    Text(errorText ?? "")
                }
        }
    }

    // MARK: - Vehicle List

    private var vehicleList: some View {
        List(availableVehicles) { vehicle in
            vehicleRow(vehicle)
        }
    }

    private func vehicleRow(_ vehicle: Vehicle) -> some View {
        Button {
            selectedVehicleId = vehicle.id
        } label: {
            HStack(spacing: 14) {
                vehicleInfo(vehicle)
                Spacer()
                if selectedVehicleId == vehicle.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(SierraTheme.Colors.alpineMint)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func vehicleInfo(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(vehicle.name) — \(vehicle.model)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Text(vehicle.licensePlate)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            if isSubmitting {
                ProgressView()
            } else {
                Button("Confirm") {
                    guard let vId = selectedVehicleId else { return }
                    Task { await reassign(vehicleId: vId) }
                }
                .disabled(selectedVehicleId == nil)
                .fontWeight(.semibold)
            }
        }
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyOverlay: some View {
        if availableVehicles.isEmpty {
            ContentUnavailableView(
                "No Available Vehicles",
                systemImage: "car.side.air.fresh",
                description: Text("All vehicles are currently in use or under maintenance.")
            )
        }
    }

    // MARK: - Reassign

    private func reassign(vehicleId: UUID) async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let trip = store.trips.first(where: { $0.id == tripId })
            let newVehicle = store.vehicle(for: vehicleId)
            try await TripService.reassignVehicle(tripId: tripId, newVehicleId: vehicleId)

            // Resolve active pre-trip defect alerts for this trip so driver card
            // unblocks from "Waiting for Vehicle" as soon as reassignment completes.
            let alertsToResolve = store.emergencyAlerts.filter { alert in
                alert.tripId == tripId
                && alert.alertType == .defect
                && (alert.status == .active || alert.status == .acknowledged)
                && (alert.description?.lowercased().contains("pre-trip fail") ?? false)
            }
            for alert in alertsToResolve {
                try? await EmergencyAlertService.resolveAlert(id: alert.id)
            }

            if
                let trip,
                let driverIdText = trip.driverId,
                let driverUUID = UUID(uuidString: driverIdText)
            {
                let plate = newVehicle?.licensePlate ?? "new vehicle"
                let title = "Vehicle Reassigned: \(trip.taskId)"
                let body = "A new vehicle (\(plate)) is assigned to your trip \(trip.origin) → \(trip.destination). Open trip details to continue pre-trip inspection."
                try? await NotificationService.insertNotification(
                    recipientId: driverUUID,
                    type: .vehicleAssigned,
                    title: title,
                    body: body,
                    entityType: "trip",
                    entityId: trip.id
                )
            }

            await store.loadAll()
            dismiss()
        } catch {
            self.errorText = error.localizedDescription
        }
    }
}
