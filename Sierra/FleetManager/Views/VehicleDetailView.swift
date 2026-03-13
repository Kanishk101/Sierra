import SwiftUI

// CHANGES IN THIS FILE (Phase 5):
// - Replaced v.registrationExpiry / v.insuranceExpiry (removed from Vehicle model) with
//   store.vehicleDocuments(for: vehicleId) rendering each VehicleDocument
// - saveChanges() now calls async throws store.updateVehicle() in a Task
// - Delete confirmation now calls async throws store.deleteVehicle(id:) in a Task
// - Fixed store.staffMember(forId:) call to correct store.staffMember(for: UUID)
// - Added @State errorMessage + showError for async error surfacing

struct VehicleDetailView: View {

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let vehicleId: UUID

    @State private var isEditing = false
    @State private var showDeleteConfirm = false
    @State private var editName = ""
    @State private var editModel = ""
    @State private var editColor = ""
    @State private var editPlate = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var vehicle: Vehicle? {
        store.vehicle(for: vehicleId)
    }

    private var documents: [VehicleDocument] {
        store.vehicleDocuments(for: vehicleId)
    }

    var body: some View {
        Group {
            if let v = vehicle {
                vehicleContent(v)
            } else {
                ContentUnavailableView("Vehicle Not Found",
                                        systemImage: "car.fill",
                                        description: Text("This vehicle may have been deleted."))
            }
        }
        .navigationTitle(vehicle?.name ?? "Vehicle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isSaving {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing { saveChanges() }
                        else { startEditing() }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .confirmationDialog("Delete Vehicle", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await store.deleteVehicle(id: vehicleId)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. All associated data will be removed.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Content

    private func vehicleContent(_ v: Vehicle) -> some View {
        List {
            // Section 1 — Vehicle Info
            Section("Vehicle Information") {
                if isEditing {
                    TextField("Name", text: $editName)
                    TextField("Model", text: $editModel)
                    TextField("Color", text: $editColor)
                    TextField("License Plate", text: $editPlate)
                } else {
                    infoRow("Name", value: v.name)
                    infoRow("Model", value: v.model)
                    infoRow("Manufacturer", value: v.manufacturer)
                    infoRow("Year", value: "\(v.year)")
                    infoRow("VIN", value: v.vin)
                    infoRow("License Plate", value: v.licensePlate)
                    infoRow("Color", value: v.color)
                    infoRow("Fuel Type", value: v.fuelType.description)
                    infoRow("Seating", value: "\(v.seatingCapacity)")
                    infoRow("Odometer", value: String(format: "%.0f km", v.odometer))
                    infoRow("Status", value: v.status.rawValue)
                }
            }

            // Section 2 — Document Status (VehicleDocument-based)
            Section("Document Status") {
                if documents.isEmpty {
                    Text("No documents on file")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(documents) { doc in
                        documentRow(doc)
                    }
                }
            }

            // Section 3 — Assignment
            Section("Assignment") {
                if let driverId = v.assignedDriverId {
                    if let driver = store.staffMember(for: driverId) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(SierraTheme.Colors.ember.opacity(0.15))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(driver.initials)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(SierraTheme.Colors.ember)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(driver.displayName)
                                    .font(SierraFont.subheadline)
                                Text(driver.phone ?? "No phone")
                                    .font(SierraFont.caption1)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(SierraFont.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Driver ID: \(driverId)")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Unassigned")
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }

            // Section 4 — Stats
            Section("Metrics") {
                infoRow("Total Trips", value: "\(v.totalTrips)")
                infoRow("Total Distance", value: String(format: "%.0f km", v.totalDistanceKm))
            }

            // Delete
            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Delete Vehicle", systemImage: "trash.fill")
                            .font(SierraFont.body(16, weight: .semibold))
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Info Row

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    // MARK: - Document Row (VehicleDocument-based)

    private func documentRow(_ doc: VehicleDocument) -> some View {
        let now = Date()
        let daysLeft = Calendar.current.dateComponents([.day], from: now, to: doc.expiryDate).day ?? 0
        let (statusText, statusColor, showWarning): (String, Color, Bool) = {
            if daysLeft < 0  { return ("Expired",      .red,                       true) }
            if daysLeft < 8  { return ("Critical",     .red,                       true) }
            if daysLeft <= 30 { return ("Expiring Soon", SierraTheme.Colors.warning, true) }
            return ("Valid", .green, false)
        }()

        return HStack {
            if showWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(SierraFont.caption1)
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(doc.documentType.rawValue)
                    .font(SierraFont.subheadline)
                Text(doc.expiryDate.formatted(date: .abbreviated, time: .omitted))
                    .font(SierraFont.caption1)
                    .foregroundStyle(.secondary)
                if !doc.issuingAuthority.isEmpty {
                    Text(doc.issuingAuthority)
                        .font(SierraFont.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(statusText)
                .font(SierraFont.caption2)
                .foregroundStyle(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.12), in: Capsule())
        }
    }

    // MARK: - Edit Actions

    private func startEditing() {
        guard let v = vehicle else { return }
        editName  = v.name
        editModel = v.model
        editColor = v.color
        editPlate = v.licensePlate
        isEditing = true
    }

    private func saveChanges() {
        guard var v = vehicle else { return }
        v.name         = editName
        v.model        = editModel
        v.color        = editColor
        v.licensePlate = editPlate
        isSaving = true
        isEditing = false
        Task {
            do {
                try await store.updateVehicle(v)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSaving = false
        }
    }
}

#Preview {
    NavigationStack {
        VehicleDetailView(vehicleId: Vehicle.mockData[0].id)
            .environment(AppDataStore.shared)
    }
}
