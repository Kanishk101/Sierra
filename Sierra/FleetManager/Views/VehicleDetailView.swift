import SwiftUI

private let navyDark = Color(hex: "0D1B2A")
private let accentOrange = Color(red: 1.0, green: 0.584, blue: 0.0)

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
                    if isEditing { saveChanges() }
                    else { startEditing() }
                }
                .fontWeight(.semibold)
            }
        }
        .confirmationDialog("Delete Vehicle", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.deleteVehicle(id: vehicleId)
                dismiss()
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
                    infoRow("Name", value: v.name)
                    infoRow("Model", value: v.model)
                    infoRow("Year", value: "\(v.year)")
                    infoRow("VIN", value: v.vin)
                    infoRow("License Plate", value: v.licensePlate)
                    infoRow("Color", value: v.color)
                    infoRow("Fuel Type", value: v.fuelType.description)
                    infoRow("Seating", value: "\(v.seatingCapacity)")
                    infoRow("Status", value: v.status.rawValue)
                }
            }

            // Section 2 — Document Status
            Section("Document Status") {
                documentRow("Registration", expiry: v.registrationExpiry)
                documentRow("Insurance", expiry: v.insuranceExpiry)
            }

            // Section 3 — Assignment
            Section("Assignment") {
                if let driverId = v.assignedDriverId {
                    if let driver = store.staffMember(forId: driverId) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(accentOrange.opacity(0.15))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(driver.initials)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(accentOrange)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(driver.name)
                                    .font(.system(size: 15, weight: .semibold))
                                Text(driver.phone)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Driver: \(driverId)")
                            .foregroundStyle(.secondary)
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
                            .font(.system(size: 16, weight: .semibold))
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

    private func documentRow(_ label: String, expiry: Date) -> some View {
        let now = Date()
        let daysLeft = Calendar.current.dateComponents([.day], from: now, to: expiry).day ?? 0
        let (statusText, statusColor, showWarning): (String, Color, Bool) = {
            if daysLeft < 0 { return ("Expired", .red, true) }
            if daysLeft < 8 { return ("Critical", .red, true) }
            if daysLeft <= 30 { return ("Expiring Soon", .orange, true) }
            return ("Valid", .green, false)
        }()

        return HStack {
            if showWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                Text(expiry.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(statusText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.12), in: Capsule())
        }
    }

    // MARK: - Edit Actions

    private func startEditing() {
        guard let v = vehicle else { return }
        editName = v.name
        editModel = v.model
        editColor = v.color
        editPlate = v.licensePlate
        isEditing = true
    }

    private func saveChanges() {
        guard var v = vehicle else { return }
        v.name = editName
        v.model = editModel
        v.color = editColor
        v.licensePlate = editPlate
        store.updateVehicle(v)
        isEditing = false
    }
}

#Preview {
    NavigationStack {
        VehicleDetailView(vehicleId: Vehicle.mockData[0].id)
            .environment(AppDataStore.shared)
    }
}
