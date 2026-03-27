import SwiftUI

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
    @State private var selectedDocumentURL: URL?
    @State private var showDocumentLoadError = false
    @State private var documentLoadErrorMessage = ""
    @State private var isLoadingDocuments = false

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
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing { Task { await saveChanges() } }
                    else { startEditing() }
                }
                .fontWeight(.semibold)
                .foregroundStyle(isEditing ? .orange : .orange)
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
        .sheet(isPresented: Binding(
            get: { selectedDocumentURL != nil },
            set: { if !$0 { selectedDocumentURL = nil } }
        )) {
            if let selectedDocumentURL {
                InAppDocumentViewer(url: selectedDocumentURL)
            }
        }
        .alert("Document Error", isPresented: $showDocumentLoadError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(documentLoadErrorMessage)
        }
        .task { await loadVehicleDocumentsIfNeeded() }
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
                    if let fuelTank = v.fuelTankCapacityLiters {
                        infoRow("Fuel Tank", value: String(format: "%.1f L", fuelTank))
                    }
                    if let mileage = v.mileageKmPerLitre {
                        infoRow("Mileage", value: String(format: "%.1f km/L", mileage))
                    }
                    infoRow("Status",        value: v.status.rawValue)
                    infoRow("Odometer",      value: String(format: "%.0f km", v.odometer))
                    infoRow("Total Trips",   value: "\(v.totalTrips)")
                }
            }

            // Section 2 — Document Status
            let docs = store.vehicleDocuments(forVehicle: vehicleId)
            Section("Document Status") {
                if isLoadingDocuments {
                    HStack {
                        ProgressView()
                        Text("Loading documents…")
                            .foregroundStyle(.secondary)
                    }
                }
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
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(driver.initials)
                                    .font(SierraFont.scaled(13, weight: .bold))
                                    .foregroundStyle(.orange)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(driver.displayName)
                                .font(.subheadline)
                            if let phone = driver.phone {
                                Text(phone)
                                    .font(.caption)
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
                            .font(SierraFont.scaled(16, weight: .semibold))
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
            if daysLeft < 0   { return ("Expired",        .red,    true)  }
            if daysLeft < 8   { return ("Critical",       .red,    true)  }
            if daysLeft <= 30 { return ("Expiring Soon",  .orange, true)  }
            return               ("Valid",            .green,  false)
        }()

        return HStack {
            if showWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(doc.documentType.rawValue)
                    .font(.subheadline)
                Text(doc.expiryDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if doc.documentUrl != nil {
                Button("View") {
                    Task { await openDocument(doc) }
                }
                .font(.caption)
            }

            Text(statusText)
                .font(.caption2)
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

    @MainActor
    private func openDocument(_ doc: VehicleDocument) async {
        guard let storedValue = doc.documentUrl, !storedValue.isEmpty else {
            documentLoadErrorMessage = "No uploaded file is linked for this document."
            showDocumentLoadError = true
            return
        }
        guard let url = VehicleDocumentService.resolveDocumentURL(storedValue: storedValue) else {
            documentLoadErrorMessage = "Unable to open this document."
            showDocumentLoadError = true
            return
        }
        selectedDocumentURL = url
    }

    // MARK: - Data Loading

    @MainActor
    private func loadVehicleDocumentsIfNeeded() async {
        guard store.vehicleDocuments(forVehicle: vehicleId).isEmpty else { return }
        isLoadingDocuments = true
        await store.refreshVehicleDocuments(vehicleId: vehicleId)
        isLoadingDocuments = false
    }
}

#Preview {
    NavigationStack {
        VehicleDetailView(vehicleId: UUID())
            .environment(AppDataStore.shared)
    }
}
