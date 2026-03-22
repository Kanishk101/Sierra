import SwiftUI

/// Form to add or edit a vehicle. Presented as .sheet.
/// Phase 13: UI only — all state and logic in AddVehicleViewModel.
struct AddVehicleView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppDataStore.self) private var store

    @State private var vm: AddVehicleViewModel

    init(editingVehicle: Vehicle? = nil, onSaved: (() -> Void)? = nil) {
        let viewModel = AddVehicleViewModel(editingVehicle: editingVehicle)
        viewModel.onSaved = onSaved
        _vm = State(initialValue: viewModel)
    }

    private func requiredLabel(_ title: String) -> Text {
        var label = AttributedString("\(title) ")
        var star = AttributedString("*")
        star.foregroundColor = .red
        label.append(star)
        return Text(label)
    }

    private func requiredPrompt(_ title: String, trailing: String? = nil) -> Text {
        var label = AttributedString("\(title) ")
        var star = AttributedString("*")
        star.foregroundColor = .red
        label.append(star)
        if let trailing, !trailing.isEmpty {
            label.append(AttributedString(" \(trailing)"))
        }
        return Text(label)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                Form {
                    basicInfoSection
                    specificationsSection
                    if !vm.isEditing { documentsSection }
                }
                .scrollContentBackground(.hidden)

                if vm.showSuccess {
                    VStack {
                        successToast
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .animation(.spring(duration: 0.4), value: vm.showSuccess)
                    .zIndex(10)
                }
            }
            .navigationTitle(vm.isEditing ? "Edit Vehicle" : "Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.isSubmitting {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button(vm.isEditing ? "Save" : "Add Vehicle") {
                            Task {
                                await vm.submit(store: store)
                                if vm.showSuccess {
                                    try? await Task.sleep(for: .milliseconds(800))
                                    dismiss()
                                }
                            }
                        }
                        .disabled(!vm.isFormValid || vm.isSubmitting)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                    }
                }
            }
            .onAppear {
                vm.prefillIfEditing()
                vm.runValidationSelfTestsIfNeeded()
            }
            .onChange(of: vm.addRegistration) { _, enabled in
                if !enabled { vm.regNumberError = nil; vm.regAuthorityError = nil }
            }
            .onChange(of: vm.addInsurance) { _, enabled in
                if !enabled { vm.insNumberError = nil; vm.insAuthorityError = nil }
            }
            .onChange(of: vm.manufacturer) { _, newManufacturer in
                guard !newManufacturer.isEmpty else { vm.model = ""; return }
                let validModels = vm.defaultVehiclePresets
                    .filter { $0.manufacturer == newManufacturer }
                    .map(\.model)
                if !validModels.contains(vm.model) {
                    vm.model = validModels.first ?? vm.model
                }
                vm.applyPresetSelectionIfNeeded()
            }
            .onChange(of: vm.name) { _, newName in
                if vm.vehicleNameOptions.contains(where: { $0.caseInsensitiveCompare(newName) == .orderedSame }) {
                    vm.selectedNameOption = vm.vehicleNameOptions.first(where: {
                        $0.caseInsensitiveCompare(newName) == .orderedSame
                    }) ?? newName
                } else if !newName.isEmpty {
                    vm.selectedNameOption = "Custom"
                }
            }
            .onChange(of: vm.manufacturer) { _, newManufacturer in
                if vm.manufacturerOptions.contains(where: { $0.caseInsensitiveCompare(newManufacturer) == .orderedSame }) {
                    vm.selectedManufacturerOption = vm.manufacturerOptions.first(where: {
                        $0.caseInsensitiveCompare(newManufacturer) == .orderedSame
                    }) ?? newManufacturer
                } else if !newManufacturer.isEmpty {
                    vm.selectedManufacturerOption = "Custom"
                }
            }
            .onChange(of: vm.model) { _, _ in vm.applyPresetSelectionIfNeeded() }
            .onChange(of: vm.model) { _, newModel in
                if vm.modelOptions.contains(where: { $0.caseInsensitiveCompare(newModel) == .orderedSame }) {
                    vm.selectedModelOption = vm.modelOptions.first(where: {
                        $0.caseInsensitiveCompare(newModel) == .orderedSame
                    }) ?? newModel
                } else if !newModel.isEmpty {
                    vm.selectedModelOption = "Custom"
                }
            }
            .alert("Error", isPresented: $vm.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "An unknown error occurred.")
            }
        }
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        Section("Basic Info") {
            Picker(selection: $vm.selectedNameOption) {
                Text("Select vehicle name").tag("")
                ForEach(vm.vehicleNameOptions, id: \.self) { option in Text(option).tag(option) }
                Text("Custom").tag("Custom")
            } label: { requiredLabel("Vehicle Name") }
            .pickerStyle(.menu)
            .onChange(of: vm.selectedNameOption) { _, newValue in
                if newValue != "Custom" { vm.name = newValue }
            }
            if vm.selectedNameOption == "Custom" {
                TextField("", text: $vm.name, prompt: requiredPrompt("Custom Vehicle Name"))
            }

            Picker(selection: $vm.selectedManufacturerOption) {
                Text("Select manufacturer").tag("")
                ForEach(vm.manufacturerOptions, id: \.self) { option in Text(option).tag(option) }
                Text("Custom").tag("Custom")
            } label: { requiredLabel("Manufacturer") }
            .pickerStyle(.menu)
            .onChange(of: vm.selectedManufacturerOption) { _, newValue in
                if newValue != "Custom" { vm.manufacturer = newValue }
            }
            if vm.selectedManufacturerOption == "Custom" {
                TextField("", text: $vm.manufacturer, prompt: requiredPrompt("Custom Manufacturer"))
            }

            Picker(selection: $vm.selectedModelOption) {
                Text("Select model").tag("")
                ForEach(vm.modelOptions, id: \.self) { option in Text(option).tag(option) }
                Text("Custom").tag("Custom")
            } label: { requiredLabel("Model") }
            .pickerStyle(.menu)
            .onChange(of: vm.selectedModelOption) { _, newValue in
                if newValue != "Custom" { vm.model = newValue }
            }
            if vm.selectedModelOption == "Custom" {
                TextField("", text: $vm.model, prompt: requiredPrompt("Custom Model"))
            }

            Picker("Year", selection: $vm.year) {
                ForEach((1990...2026).reversed(), id: \.self) { y in Text(String(y)).tag(y) }
            }

            VStack(alignment: .leading, spacing: 4) {
                TextField("", text: $vm.vin, prompt: requiredPrompt("VIN", trailing: "(17 characters)"))
                    .textInputAutocapitalization(.characters)
                    .onChange(of: vm.vin) { _, newVal in
                        vm.vin = String(newVal.uppercased().prefix(17))
                        vm.vinError = vm.vinValidationError(for: vm.vin)
                    }
                if let err = vm.vinError {
                    Text(err).font(.caption2).foregroundStyle(.red)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                TextField("", text: $vm.licensePlate, prompt: requiredPrompt("License Plate"))
                    .textInputAutocapitalization(.characters)
                    .onChange(of: vm.licensePlate) { _, newValue in
                        vm.licensePlate = String(newValue.uppercased().prefix(13))
                        vm.licensePlateError = vm.licensePlateValidationError(for: vm.licensePlate)
                    }
                if let err = vm.licensePlateError {
                    Text(err).font(.caption2).foregroundStyle(.red)
                }
            }

            Picker(selection: $vm.selectedColorOption) {
                Text("Select color").tag("")
                ForEach(vm.colorOptions, id: \.self) { option in Text(option).tag(option) }
                Text("Custom").tag("Custom")
            } label: { requiredLabel("Color") }
            .pickerStyle(.menu)
            .onChange(of: vm.selectedColorOption) { _, newValue in
                if newValue != "Custom" { vm.color = newValue; vm.colorError = nil }
            }

            if vm.selectedColorOption == "Custom" {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("", text: $vm.color, prompt: requiredPrompt("Custom Color"))
                        .onChange(of: vm.color) { _, newValue in
                            let filtered = String(newValue.filter { $0.isLetter || $0 == " " })
                            if filtered != newValue { vm.color = filtered }
                            vm.colorError = vm.colorValidationError(for: filtered)
                        }
                    if let err = vm.colorError {
                        Text(err).font(.caption2).foregroundStyle(.red)
                    }
                }
            }
        }
    }

    // MARK: - Specifications Section

    private var specificationsSection: some View {
        Section("Specifications") {
            Picker("Fuel Type", selection: $vm.fuelType) {
                ForEach(FuelType.allCases, id: \.self) { ft in Text(ft.description).tag(ft) }
            }
            Stepper("Seating: \(vm.seatingCapacity)", value: $vm.seatingCapacity, in: 1...50)
        }
    }

    // MARK: - Documents Section

    @ViewBuilder
    private var documentsSection: some View {
        Section { Toggle("Add Registration Document", isOn: $vm.addRegistration.animation()) }
        header: { Text("Documents (Optional)") }

        if vm.addRegistration {
            Section("Registration") {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Document Number", text: $vm.regNumber)
                        .textInputAutocapitalization(.characters)
                        .onChange(of: vm.regNumber) { _, newValue in
                            vm.regNumber = newValue.uppercased()
                            vm.regNumberError = vm.registrationNumberValidationError(for: vm.regNumber)
                        }
                    if let err = vm.regNumberError { Text(err).font(.caption2).foregroundStyle(.red) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Issuing Authority", text: $vm.regAuthority)
                        .onChange(of: vm.regAuthority) { _, newValue in
                            vm.regAuthorityError = vm.issuingAuthorityValidationError(for: newValue, fieldName: "Issuing authority")
                        }
                    if let err = vm.regAuthorityError { Text(err).font(.caption2).foregroundStyle(.red) }
                }
                DatePicker("Issued Date", selection: $vm.regIssued, displayedComponents: .date)
                DatePicker("Expiry Date", selection: $vm.regExpiry, in: Date()..., displayedComponents: .date)
            }
        }

        Section { Toggle("Add Insurance Document", isOn: $vm.addInsurance.animation()) }

        if vm.addInsurance {
            Section("Insurance") {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Policy Number", text: $vm.insNumber)
                        .textInputAutocapitalization(.characters)
                        .onChange(of: vm.insNumber) { _, newValue in
                            vm.insNumber = newValue.uppercased()
                            vm.insNumberError = vm.insurancePolicyValidationError(for: vm.insNumber)
                        }
                    if let err = vm.insNumberError { Text(err).font(.caption2).foregroundStyle(.red) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Insurer Name", text: $vm.insAuthority)
                        .onChange(of: vm.insAuthority) { _, newValue in
                            vm.insAuthorityError = vm.issuingAuthorityValidationError(for: newValue, fieldName: "Insurer name")
                        }
                    if let err = vm.insAuthorityError { Text(err).font(.caption2).foregroundStyle(.red) }
                }
                DatePicker("Issued Date", selection: $vm.insIssued, displayedComponents: .date)
                DatePicker("Expiry Date", selection: $vm.insExpiry, in: Date()..., displayedComponents: .date)
            }
        }
    }

    // MARK: - Success Toast

    private var successToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
            Text(vm.isEditing ? "Vehicle updated!" : "Vehicle added!")
                .font(.subheadline).foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.green, in: Capsule())
        .padding(.top, 8)
    }
}

#Preview {
    AddVehicleView()
        .environment(AppDataStore.shared)
}
