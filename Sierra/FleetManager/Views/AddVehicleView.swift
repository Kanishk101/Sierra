import SwiftUI

private let navyDark = Color(hex: "0D1B2A")
private let accentOrange = Color(red: 1.0, green: 0.584, blue: 0.0)

/// Form to add or edit a vehicle. Presented as .sheet.
struct AddVehicleView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppDataStore.self) private var store

    /// If editing, pass the vehicle to pre-fill.
    var editingVehicle: Vehicle?
    var onSaved: (() -> Void)?

    // MARK: - Form State

    @State private var name = ""
    @State private var model = ""
    @State private var year = 2025
    @State private var vin = ""
    @State private var licensePlate = ""
    @State private var color = ""
    @State private var fuelType: FuelType = .diesel
    @State private var seatingCapacity = 3
    @State private var registrationExpiry = Date()
    @State private var insuranceExpiry = Date()

    @State private var showSuccess = false
    @State private var vinError: String?

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
                Color(hex: "F2F3F7").ignoresSafeArea()

                Form {
                    // Basic Info
                    Section("Basic Info") {
                        TextField("Vehicle Name *", text: $name)
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
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red)
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

                    // Documents
                    Section("Documents") {
                        DatePicker("Registration Expiry *",
                                   selection: $registrationExpiry,
                                   in: Date()...,
                                   displayedComponents: .date)
                        DatePicker("Insurance Expiry *",
                                   selection: $insuranceExpiry,
                                   in: Date()...,
                                   displayedComponents: .date)
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
                    Button(isEditing ? "Save" : "Add Vehicle") {
                        submitForm()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.semibold)
                }
            }
            .onAppear { prefillIfEditing() }
        }
    }

    // MARK: - Success Toast

    private var successToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)
            Text(isEditing ? "Vehicle updated!" : "Vehicle added!")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.green, in: Capsule())
        .padding(.top, 8)
    }

    // MARK: - Submit

    private func submitForm() {
        // Validate VIN
        guard isVinValid else {
            vinError = "VIN must be exactly 17 alphanumeric characters"
            return
        }

        if isEditing, var v = editingVehicle {
            v.name = name
            v.model = model
            v.year = year
            v.vin = vin
            v.licensePlate = licensePlate
            v.color = color
            v.fuelType = fuelType
            v.seatingCapacity = seatingCapacity
            v.registrationExpiry = registrationExpiry
            v.insuranceExpiry = insuranceExpiry
            store.updateVehicle(v)
        } else {
            let vehicle = Vehicle(
                id: UUID(),
                name: name.trimmingCharacters(in: .whitespaces),
                model: model.trimmingCharacters(in: .whitespaces),
                licensePlate: licensePlate.trimmingCharacters(in: .whitespaces).uppercased(),
                status: .idle,
                year: year,
                vin: vin.trimmingCharacters(in: .whitespaces).uppercased(),
                color: color.trimmingCharacters(in: .whitespaces),
                fuelType: fuelType,
                seatingCapacity: seatingCapacity,
                registrationExpiry: registrationExpiry,
                insuranceExpiry: insuranceExpiry,
                assignedDriverId: nil,
                manufacturer: nil,
                latitude: nil,
                longitude: nil,
                mileage: 0,
                numberOfTrips: 0,
                distanceTravelled: 0,
                insuranceId: nil,
                createdAt: Date()
            )
            store.addVehicle(vehicle)
        }

        withAnimation { showSuccess = true }
        onSaved?()

        Task {
            try? await Task.sleep(for: .milliseconds(800))
            dismiss()
        }
    }

    // MARK: - Prefill

    private func prefillIfEditing() {
        guard let v = editingVehicle else { return }
        name = v.name
        model = v.model
        year = v.year
        vin = v.vin
        licensePlate = v.licensePlate
        color = v.color
        fuelType = v.fuelType
        seatingCapacity = v.seatingCapacity
        registrationExpiry = v.registrationExpiry
        insuranceExpiry = v.insuranceExpiry
    }
}

#Preview {
    AddVehicleView()
        .environment(AppDataStore.shared)
}
