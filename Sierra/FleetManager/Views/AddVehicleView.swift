import SwiftUI

// CHANGES IN THIS FILE (Phase 5):
// - Removed registrationExpiry, insuranceExpiry fields (moved to VehicleDocument)
// - Removed Vehicle(registrationExpiry:insuranceExpiry:insuranceId:) init params (no longer on model)
// - Fixed Vehicle init to match current model (manufacturer, odometer, totalTrips, totalDistanceKm)
// - Added optional "Add Documents" section to create initial VehicleDocument records post-creation
// - submitForm() is now async — calls async throws store.addVehicle/updateVehicle inside Task
// - Added error state for failed submissions

/// Form to add or edit a vehicle. Presented as .sheet.
struct AddVehicleView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppDataStore.self) private var store

    /// If editing, pass the vehicle to pre-fill.
    var editingVehicle: Vehicle?
    var onSaved: (() -> Void)?

    // MARK: - Vehicle Form State

    @State private var name = ""
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var year = 2025
    @State private var vin = ""
    @State private var licensePlate = ""
    @State private var color = ""
    @State private var fuelType: FuelType = .diesel
    @State private var seatingCapacity = 3

    // MARK: - Document Form State (initial docs — only shown on add, not edit)

    @State private var addRegistration = false
    @State private var regNumber = ""
    @State private var regIssued = Date()
    @State private var regExpiry = Date().addingTimeInterval(86400 * 365)
    @State private var regAuthority = ""

    @State private var addInsurance = false
    @State private var insNumber = ""
    @State private var insIssued = Date()
    @State private var insExpiry = Date().addingTimeInterval(86400 * 365)
    @State private var insAuthority = ""

    // MARK: - UI State

    @State private var showSuccess = false
    @State private var isSubmitting = false
    @State private var vinError: String?
    @State private var errorMessage: String?
    @State private var showError = false

    private var isEditing: Bool { editingVehicle != nil }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && !model.trimmingCharacters(in: .whitespaces).isEmpty
        && isVinValid
        && !licensePlate.trimmingCharacters(in: .whitespaces).isEmpty
        && !color.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isVinValid: Bool {
        let trimmed = vin.trimmingCharacters(in: .whitespaces)
        return trimmed.count == 17 && trimmed.range(of: "^[A-Za-z0-9]{17}$", options: .regularExpression) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SierraTheme.Colors.appBackground.ignoresSafeArea()

                Form {
                    // Basic Info
                    Section("Basic Info") {
                        TextField("Vehicle Name *", text: $name)
                        TextField("Manufacturer *", text: $manufacturer)
                        TextField("Model *", text: $model)
                        Picker("Year", selection: $year) {
                            ForEach((1990...2026).reversed(), id: \.self) { y in
                                Text(String(y)).tag(y)
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("VIN * (17 characters)", text: $vin)
                                .textInputAutocapitalization(.characters)
                                .onChange(of: vin) { _, newVal in
                                    vin = String(newVal.prefix(17))
                                    vinError = nil
                                }
                            if let err = vinError {
                                Text(err)
                                    .font(SierraFont.caption2)
                                    .foregroundStyle(SierraTheme.Colors.danger)
                            }
                        }
                        TextField("License Plate *", text: $licensePlate)
                            .textInputAutocapitalization(.characters)
                        TextField("Color *", text: $color)
                    }

                    // Specs
                    Section("Specifications") {
                        Picker("Fuel Type", selection: $fuelType) {
                            ForEach(FuelType.allCases, id: \.self) { ft in
                                Text(ft.description).tag(ft)
                            }
                        }
                        Stepper("Seating: \(seatingCapacity)", value: $seatingCapacity, in: 1...50)
                    }

                    // Documents (only shown when adding a new vehicle)
                    if !isEditing {
                        Section {
                            Toggle("Add Registration Document", isOn: $addRegistration.animation())
                        } header: {
                            Text("Documents (Optional)")
                        }

                        if addRegistration {
                            Section("Registration") {
                                TextField("Document Number", text: $regNumber)
                                TextField("Issuing Authority", text: $regAuthority)
                                DatePicker("Issued Date", selection: $regIssued, displayedComponents: .date)
                                DatePicker("Expiry Date", selection: $regExpiry, in: Date()..., displayedComponents: .date)
                            }
                        }

                        Section {
                            Toggle("Add Insurance Document", isOn: $addInsurance.animation())
                        }

                        if addInsurance {
                            Section("Insurance") {
                                TextField("Policy Number", text: $insNumber)
                                TextField("Insurer Name", text: $insAuthority)
                                DatePicker("Issued Date", selection: $insIssued, displayedComponents: .date)
                                DatePicker("Expiry Date", selection: $insExpiry, in: Date()..., displayedComponents: .date)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)

                // Success toast
                if showSuccess {
                    VStack {
                        successToast
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .animation(.spring(duration: 0.4), value: showSuccess)
                    .zIndex(10)
                }
            }
            .navigationTitle(isEditing ? "Edit Vehicle" : "Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button(isEditing ? "Save" : "Add Vehicle") {
                            Task { await submitForm() }
                        }
                        .disabled(!isFormValid || isSubmitting)
                        .fontWeight(.semibold)
                    }
                }
            }
            .onAppear { prefillIfEditing() }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
        }
    }

    // MARK: - Success Toast

    private var successToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)
            Text(isEditing ? "Vehicle updated!" : "Vehicle added!")
                .font(SierraFont.subheadline)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.green, in: Capsule())
        .padding(.top, 8)
    }

    // MARK: - Submit

    private func submitForm() async {
        guard isVinValid else {
            vinError = "VIN must be exactly 17 alphanumeric characters"
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            if isEditing, var v = editingVehicle {
                v.name         = name.trimmingCharacters(in: .whitespaces)
                v.manufacturer = manufacturer.trimmingCharacters(in: .whitespaces)
                v.model        = model.trimmingCharacters(in: .whitespaces)
                v.year         = year
                v.vin          = vin.trimmingCharacters(in: .whitespaces).uppercased()
                v.licensePlate = licensePlate.trimmingCharacters(in: .whitespaces).uppercased()
                v.color        = color.trimmingCharacters(in: .whitespaces)
                v.fuelType     = fuelType
                v.seatingCapacity = seatingCapacity
                try await store.updateVehicle(v)
            } else {
                let now = Date()
                let vehicle = Vehicle(
                    id: UUID(),
                    name: name.trimmingCharacters(in: .whitespaces),
                    manufacturer: manufacturer.trimmingCharacters(in: .whitespaces),
                    model: model.trimmingCharacters(in: .whitespaces),
                    year: year,
                    vin: vin.trimmingCharacters(in: .whitespaces).uppercased(),
                    licensePlate: licensePlate.trimmingCharacters(in: .whitespaces).uppercased(),
                    color: color.trimmingCharacters(in: .whitespaces),
                    fuelType: fuelType,
                    seatingCapacity: seatingCapacity,
                    status: .idle,
                    assignedDriverId: nil,
                    currentLatitude: nil,
                    currentLongitude: nil,
                    odometer: 0.0,
                    totalTrips: 0,
                    totalDistanceKm: 0.0,
                    createdAt: now,
                    updatedAt: now
                )
                try await store.addVehicle(vehicle)

                // Add optional initial documents
                if addRegistration && !regNumber.trimmingCharacters(in: .whitespaces).isEmpty {
                    let doc = VehicleDocument(
                        id: UUID(),
                        vehicleId: vehicle.id,
                        documentType: .registration,
                        documentNumber: regNumber.trimmingCharacters(in: .whitespaces),
                        issuedDate: regIssued,
                        expiryDate: regExpiry,
                        issuingAuthority: regAuthority.trimmingCharacters(in: .whitespaces),
                        documentUrl: nil,
                        notes: nil,
                        createdAt: now,
                        updatedAt: now
                    )
                    try await store.addVehicleDocument(doc)
                }

                if addInsurance && !insNumber.trimmingCharacters(in: .whitespaces).isEmpty {
                    let doc = VehicleDocument(
                        id: UUID(),
                        vehicleId: vehicle.id,
                        documentType: .insurance,
                        documentNumber: insNumber.trimmingCharacters(in: .whitespaces),
                        issuedDate: insIssued,
                        expiryDate: insExpiry,
                        issuingAuthority: insAuthority.trimmingCharacters(in: .whitespaces),
                        documentUrl: nil,
                        notes: nil,
                        createdAt: now,
                        updatedAt: now
                    )
                    try await store.addVehicleDocument(doc)
                }
            }

            withAnimation { showSuccess = true }
            onSaved?()
            try? await Task.sleep(for: .milliseconds(800))
            dismiss()

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Prefill

    private func prefillIfEditing() {
        guard let v = editingVehicle else { return }
        name         = v.name
        manufacturer = v.manufacturer
        model        = v.model
        year         = v.year
        vin          = v.vin
        licensePlate = v.licensePlate
        color        = v.color
        fuelType     = v.fuelType
        seatingCapacity = v.seatingCapacity
    }
}

#Preview {
    AddVehicleView()
        .environment(AppDataStore.shared)
}
