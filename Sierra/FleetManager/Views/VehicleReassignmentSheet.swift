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
            try await TripService.reassignVehicle(tripId: tripId, newVehicleId: vehicleId)
            await store.loadAll()
            dismiss()
        } catch {
            self.errorText = error.localizedDescription
        }
    }
}
