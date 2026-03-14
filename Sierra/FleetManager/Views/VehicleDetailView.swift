import SwiftUI

// CHANGES (Phase 1 restore):
// - Restored native List/Section layout from current branch (removed ScrollView card layout)
// - Document Status section now uses store.vehicleDocuments(forVehicle:) instead of removed fields
// - All store mutations are async (wrapped in Task)
// - Inline Edit/Save mode preserved exactly from current branch
// - Delete button + confirmationDialog preserved exactly from current branch
// - driver.name → driver.displayName

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

    private var vehicle: Vehicle? {
        store.vehicles.first { $0.id == vehicleId }
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
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing { Task { await saveChanges() } }
                    else { startEditing() }
                }
                .fontWeight(.semibold)
            }
        }
        .confirmationDialog("Delete Vehicle", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await store.deleteVehicle(id: vehicleId)
                        dismiss()
                    } catch {
                        print("[VehicleDetailView] Delete error: \(error)")
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. All associated data will be removed.")
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
                    infoRow("Name",          value: v.name)
                    infoRow("Manufacturer",  value: v.manufacturer)
                    infoRow("Model",         value: v.model)
                    infoRow("Year",          value: "\(v.year)")
                    infoRow("VIN",           value: v.vin)
                    infoRow("License Plate", value: v.licensePlate)
                    infoRow("Color",         value: v.color)
                    infoRow("Fuel Type",     value: v.fuelType.rawValue)
                    infoRow("Seating",       value: "\(v.seatingCapacity)")
                    infoRow("Status",        value: v.status.rawValue)
                    infoRow("Odometer",      value: String(format: "%.0f km", v.odometer))
                    infoRow("Total Trips",   value: "\(v.totalTrips)")
                }
            }

            // Section 2 — Document Status
            let docs = store.vehicleDocuments(forVehicle: vehicleId)
            Section("Document Status") {
                if docs.isEmpty {
                    Text("No documents on file")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(docs) { doc in
                        documentRow(doc)
                    }
                }
            }

            // Section 3 — Assignment
            Section("Assignment") {
                if let driverIdStr = v.assignedDriverId,
                   let driverUUID = UUID(uuidString: driverIdStr),
                   let driver = store.staffMember(for: driverUUID) {
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
                            if let phone = driver.phone {
                                Text(phone)
                                    .font(SierraFont.caption1)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                } else {
                    Text("Unassigned")
                        .foregroundStyle(.secondary)
                        .italic()
                }
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

    // MARK: - Helpers

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    private func documentRow(_ doc: VehicleDocument) -> some View {
        let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: doc.expiryDate).day ?? 0
        let (statusText, statusColor, showWarning): (String, Color, Bool) = {
            if daysLeft < 0   { return ("Expired",        .red,                       true)  }
            if daysLeft < 8   { return ("Critical",       .red,                       true)  }
            if daysLeft <= 30 { return ("Expiring Soon",  SierraTheme.Colors.warning, true)  }
            return               ("Valid",            .green,                    false)
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

    @MainActor
    private func saveChanges() async {
        guard var v = vehicle else { return }
        v.name         = editName
        v.model        = editModel
        v.color        = editColor
        v.licensePlate = editPlate
        do {
            try await store.updateVehicle(v)
            isEditing = false
        } catch {
            print("[VehicleDetailView] Save error: \(error)")
            isEditing = false
        }
    }
}

#Preview {
    NavigationStack {
        VehicleDetailView(vehicleId: UUID())
            .environment(AppDataStore.shared)
    }
}
