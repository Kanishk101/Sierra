import SwiftUI

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
    @State private var selectedNameOption = ""
    @State private var selectedManufacturerOption = ""
    @State private var selectedModelOption = ""
    @State private var year = 2025
    @State private var vin = ""
    @State private var licensePlate = ""
    @State private var color = ""
    @State private var selectedColorOption = ""
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
    @State private var licensePlateError: String?
    @State private var colorError: String?
    @State private var regNumberError: String?
    @State private var regAuthorityError: String?
    @State private var insNumberError: String?
    @State private var insAuthorityError: String?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var didRunValidationSelfTests = false

    private var isEditing: Bool { editingVehicle != nil }

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

    private let defaultVehicleColors: [String] = [
        "White", "Silver", "Gray", "Black", "Blue",
        "Red", "Brown", "Green", "Yellow", "Orange"
    ]

    private var colorOptions: [String] {
        var options = defaultVehicleColors
        let trimmedColor = color.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedColor.isEmpty && !options.contains(where: { $0.caseInsensitiveCompare(trimmedColor) == .orderedSame }) {
            options.append(trimmedColor)
        }
        return options
    }

    private struct VehiclePreset: Hashable {
        let name: String
        let manufacturer: String
        let model: String
    }

    private let defaultVehiclePresets: [VehiclePreset] = [
        .init(name: "Tata Signa 4825", manufacturer: "Tata", model: "Signa 4825"),
        .init(name: "Ashok Leyland 2820", manufacturer: "Ashok Leyland", model: "2820"),
        .init(name: "Mahindra Blazo X 35", manufacturer: "Mahindra", model: "Blazo X 35"),
        .init(name: "Eicher Pro 3015", manufacturer: "Eicher", model: "Pro 3015"),
        .init(name: "BharatBenz 3528C", manufacturer: "BharatBenz", model: "3528C"),
        .init(name: "Volvo FM 420", manufacturer: "Volvo", model: "FM 420"),
        .init(name: "Scania G 410", manufacturer: "Scania", model: "G 410"),
        .init(name: "Mercedes-Benz Actros", manufacturer: "Mercedes-Benz", model: "Actros 2545"),
        .init(name: "Ford Transit", manufacturer: "Ford", model: "Transit"),
        .init(name: "Toyota Hilux", manufacturer: "Toyota", model: "Hilux")
    ]

    private var manufacturerOptions: [String] {
        var ordered: [String] = []
        for preset in defaultVehiclePresets where !ordered.contains(preset.manufacturer) {
            ordered.append(preset.manufacturer)
        }
        let trimmedManufacturer = manufacturer.trimmingCharacters(in: .whitespaces)
        if !trimmedManufacturer.isEmpty && !ordered.contains(trimmedManufacturer) {
            ordered.append(trimmedManufacturer)
        }
        return ordered
    }

    private var modelOptions: [String] {
        let optionsFromManufacturer: [String]
        if manufacturer.isEmpty {
            optionsFromManufacturer = defaultVehiclePresets.map(\.model)
        } else {
            optionsFromManufacturer = defaultVehiclePresets
                .filter { $0.manufacturer == manufacturer }
                .map(\.model)
        }

        var ordered: [String] = []
        for modelName in optionsFromManufacturer where !ordered.contains(modelName) {
            ordered.append(modelName)
        }
        let trimmedModel = model.trimmingCharacters(in: .whitespaces)
        if !trimmedModel.isEmpty && !ordered.contains(trimmedModel) {
            ordered.append(trimmedModel)
        }
        return ordered
    }

    private var vehicleNameOptions: [String] {
        let filtered: [VehiclePreset]
        if !manufacturer.isEmpty && !model.isEmpty {
            filtered = defaultVehiclePresets.filter { $0.manufacturer == manufacturer && $0.model == model }
        } else if !manufacturer.isEmpty {
            filtered = defaultVehiclePresets.filter { $0.manufacturer == manufacturer }
        } else {
            filtered = defaultVehiclePresets
        }

        var ordered: [String] = []
        for preset in filtered where !ordered.contains(preset.name) {
            ordered.append(preset.name)
        }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty && !ordered.contains(trimmedName) {
            ordered.append(trimmedName)
        }
        return ordered
    }

    private var presetNames: Set<String> {
        Set(defaultVehiclePresets.map(\.name))
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && !model.trimmingCharacters(in: .whitespaces).isEmpty
        && vinValidationError(for: vin) == nil
        && licensePlateValidationError(for: licensePlate) == nil
        && colorValidationError(for: color) == nil
    }

    private var manufacturerWMIMap: [String: Set<String>] {
        [
            "Maruti": ["MA3"],
            "Tata": ["MAT"],
            "Mahindra": ["MBH"]
        ]
    }

    private var allowedVinYearCodes: Set<Character> {
        Set("ABCDEFGHJKLMNPRSTVWXY123456789")
    }

    private var allowedVinMonthCodes: Set<Character> {
        Set("ABCDEFGHJKLM")
    }

    private func vinValidationError(for rawVIN: String, manufacturerOverride: String? = nil) -> String? {
        let trimmed = rawVIN
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !trimmed.isEmpty else { return "VIN is required." }
        guard trimmed.count == 17 else { return "VIN must be exactly 17 characters." }
        guard trimmed.range(of: "^[A-Z0-9]{17}$", options: .regularExpression) != nil else {
            return "VIN must contain only letters and numbers."
        }
        guard trimmed.range(of: "[IOQ]", options: .regularExpression) == nil else {
            return "VIN cannot contain I, O, or Q."
        }

        let manufacturerForCheck = manufacturerOverride ?? manufacturer
        if !manufacturerForCheck.isEmpty {
            for (maker, wmis) in manufacturerWMIMap where manufacturerForCheck.localizedCaseInsensitiveContains(maker) {
                let wmi = String(trimmed.prefix(3))
                if !wmis.contains(wmi) {
                    let expected = wmis.sorted().joined(separator: ", ")
                    return "WMI mismatch for \(maker). Expected prefix: \(expected)."
                }
                break
            }
        }

        let chars = Array(trimmed)
        let yearCode = chars[9]   // 10th char
        guard allowedVinYearCodes.contains(yearCode) else {
            return "10th character (year code) is invalid."
        }

        // Some manufacturers encode month in 12th/13th positions.
        // If alphabetic values are present, ensure they are valid month codes A-M (excluding I).
        for idx in [11, 12] {
            let c = chars[idx]
            if c.isLetter && !allowedVinMonthCodes.contains(c) {
                return "\(idx + 1)th character has invalid month code."
            }
        }

        return nil
    }

    private func licensePlateValidationError(for rawPlate: String) -> String? {
        let trimmed = rawPlate.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return "License plate is required." }
        guard trimmed.count <= 13 else { return "License plate cannot be longer than 13 characters." }

        // Accept with or without separators (space/hyphen).
        let normalized = trimmed.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")

        // Format: SS DD SSS NNNN
        // SS: state/UT (2 letters)
        // DD: RTO (2 digits)
        // SSS: 1..3 letters (excluding I and O)
        // NNNN: 4 digits, numeric value 1...9999
        let pattern = #"^[A-Z]{2}[0-9]{2}[A-HJ-NP-Z]{1,3}[0-9]{4}$"#
        guard normalized.range(of: pattern, options: .regularExpression) != nil else {
            return "Format must be like MH12AB1234 (state + RTO + series + 4 digits)."
        }

        let start = normalized.startIndex
        let seriesStart = normalized.index(start, offsetBy: 4)
        let numberStart = normalized.index(normalized.endIndex, offsetBy: -4)
        let series = String(normalized[seriesStart..<numberStart])
        if series.contains("I") || series.contains("O") {
            return "Series letters cannot include I or O."
        }

        let uniqueNumber = String(normalized[numberStart...])
        if let number = Int(uniqueNumber), number == 0 {
            return "Unique number must be from 0001 to 9999."
        }

        return nil
    }

    private func colorValidationError(for rawColor: String) -> String? {
        let trimmed = rawColor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Color is required." }
        guard trimmed.range(of: "^[A-Za-z ]+$", options: .regularExpression) != nil else {
            return "Color can contain only alphabets."
        }
        return nil
    }

    private func registrationNumberValidationError(for rawNumber: String) -> String? {
        let trimmed = rawNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return "Registration document number is required." }
        guard trimmed.range(of: "^[A-Z0-9 -]+$", options: .regularExpression) != nil else {
            return "Use only English letters, digits, spaces or hyphens."
        }

        let normalized = trimmed.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")

        let standardPattern = #"^[A-Z]{2}[0-9]{2}[A-Z]{1,3}[0-9]{4}$"#
        let bhPattern = #"^[0-9]{2}BH[0-9]{4}[A-Z]{1,2}$"#
        let vaPattern = #"^[A-Z]{2}VA[A-Z]{2}[0-9]{4}$"#
        let temporaryPattern = #"^T[0-9]{4}[A-Z]{2}[0-9]{4}[A-Z]{2}$"#
        let tradePattern = #"^[A-Z]{2}[0-9]{2}[A-Z][0-9]{4}TC[0-9]{4}$"#

        let patterns = [standardPattern, bhPattern, vaPattern, temporaryPattern, tradePattern]
        let isValid = patterns.contains { normalized.range(of: $0, options: .regularExpression) != nil }
        if !isValid {
            return "Invalid RC format. Use standard/BH/VA/T/TC approved format."
        }
        return nil
    }

    private func issuingAuthorityValidationError(for rawAuthority: String, fieldName: String) -> String? {
        let trimmed = rawAuthority.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "\(fieldName) is required." }
        guard trimmed.count >= 3 else { return "\(fieldName) must be at least 3 characters." }
        guard trimmed.range(of: "^[A-Za-z .&()-]+$", options: .regularExpression) != nil else {
            return "\(fieldName) can contain only letters and common separators."
        }
        return nil
    }

    private func insurancePolicyValidationError(for rawNumber: String) -> String? {
        let trimmed = rawNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return "Policy number is required." }
        guard trimmed.range(of: "^[A-Z0-9/-]{6,24}$", options: .regularExpression) != nil else {
            return "Policy number must be 6–24 characters (letters/digits/-/)."
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                Form {
                    // Basic Info
                    Section("Basic Info") {
                        Picker(selection: $selectedNameOption) {
                            Text("Select vehicle name").tag("")
                            ForEach(vehicleNameOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                            Text("Custom").tag("Custom")
                        } label: {
                            requiredLabel("Vehicle Name")
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedNameOption) { _, newValue in
                            if newValue != "Custom" {
                                name = newValue
                            }
                        }
                        if selectedNameOption == "Custom" {
                            TextField("", text: $name, prompt: requiredPrompt("Custom Vehicle Name"))
                        }

                        Picker(selection: $selectedManufacturerOption) {
                            Text("Select manufacturer").tag("")
                            ForEach(manufacturerOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                            Text("Custom").tag("Custom")
                        } label: {
                            requiredLabel("Manufacturer")
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedManufacturerOption) { _, newValue in
                            if newValue != "Custom" {
                                manufacturer = newValue
                            }
                        }
                        if selectedManufacturerOption == "Custom" {
                            TextField("", text: $manufacturer, prompt: requiredPrompt("Custom Manufacturer"))
                        }

                        Picker(selection: $selectedModelOption) {
                            Text("Select model").tag("")
                            ForEach(modelOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                            Text("Custom").tag("Custom")
                        } label: {
                            requiredLabel("Model")
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedModelOption) { _, newValue in
                            if newValue != "Custom" {
                                model = newValue
                            }
                        }
                        if selectedModelOption == "Custom" {
                            TextField("", text: $model, prompt: requiredPrompt("Custom Model"))
                        }

                        Picker("Year", selection: $year) {
                            ForEach((1990...2026).reversed(), id: \.self) { y in
                                Text(String(y)).tag(y)
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("", text: $vin, prompt: requiredPrompt("VIN", trailing: "(17 characters)"))
                                .textInputAutocapitalization(.characters)
                                .onChange(of: vin) { _, newVal in
                                    vin = String(newVal.uppercased().prefix(17))
                                    vinError = vinValidationError(for: vin)
                                }
                            if let err = vinError {
                                Text(err)
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("", text: $licensePlate, prompt: requiredPrompt("License Plate"))
                                .textInputAutocapitalization(.characters)
                                .onChange(of: licensePlate) { _, newValue in
                                    licensePlate = String(newValue.uppercased().prefix(13))
                                    licensePlateError = licensePlateValidationError(for: licensePlate)
                                }
                            if let err = licensePlateError {
                                Text(err)
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
                        Picker(selection: $selectedColorOption) {
                            Text("Select color").tag("")
                            ForEach(colorOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                            Text("Custom").tag("Custom")
                        } label: {
                            requiredLabel("Color")
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedColorOption) { _, newValue in
                            if newValue != "Custom" {
                                color = newValue
                                colorError = nil
                            }
                        }

                        if selectedColorOption == "Custom" {
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("", text: $color, prompt: requiredPrompt("Custom Color"))
                                    .onChange(of: color) { _, newValue in
                                        let filtered = String(newValue.filter { $0.isLetter || $0 == " " })
                                        if filtered != newValue {
                                            color = filtered
                                        }
                                        colorError = colorValidationError(for: filtered)
                                    }
                                if let err = colorError {
                                    Text(err)
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
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
                                VStack(alignment: .leading, spacing: 4) {
                                    TextField("Document Number", text: $regNumber)
                                        .textInputAutocapitalization(.characters)
                                        .onChange(of: regNumber) { _, newValue in
                                            regNumber = newValue.uppercased()
                                            regNumberError = registrationNumberValidationError(for: regNumber)
                                        }
                                    if let err = regNumberError {
                                        Text(err)
                                            .font(.caption2)
                                            .foregroundStyle(.red)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    TextField("Issuing Authority", text: $regAuthority)
                                        .onChange(of: regAuthority) { _, newValue in
                                            regAuthorityError = issuingAuthorityValidationError(
                                                for: newValue,
                                                fieldName: "Issuing authority"
                                            )
                                        }
                                    if let err = regAuthorityError {
                                        Text(err)
                                            .font(.caption2)
                                            .foregroundStyle(.red)
                                    }
                                }
                                DatePicker("Issued Date", selection: $regIssued, displayedComponents: .date)
                                DatePicker("Expiry Date", selection: $regExpiry, in: Date()..., displayedComponents: .date)
                            }
                        }

                        Section {
                            Toggle("Add Insurance Document", isOn: $addInsurance.animation())
                        }

                        if addInsurance {
                            Section("Insurance") {
                                VStack(alignment: .leading, spacing: 4) {
                                    TextField("Policy Number", text: $insNumber)
                                        .textInputAutocapitalization(.characters)
                                        .onChange(of: insNumber) { _, newValue in
                                            insNumber = newValue.uppercased()
                                            insNumberError = insurancePolicyValidationError(for: insNumber)
                                        }
                                    if let err = insNumberError {
                                        Text(err)
                                            .font(.caption2)
                                            .foregroundStyle(.red)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    TextField("Insurer Name", text: $insAuthority)
                                        .onChange(of: insAuthority) { _, newValue in
                                            insAuthorityError = issuingAuthorityValidationError(
                                                for: newValue,
                                                fieldName: "Insurer name"
                                            )
                                        }
                                    if let err = insAuthorityError {
                                        Text(err)
                                            .font(.caption2)
                                            .foregroundStyle(.red)
                                    }
                                }
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
                        .foregroundStyle(.secondary)
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
                        .foregroundStyle(.orange)
                    }
                }
            }
            .onAppear {
                prefillIfEditing()
                runValidationSelfTestsIfNeeded()
            }
            .onChange(of: addRegistration) { _, enabled in
                if !enabled {
                    regNumberError = nil
                    regAuthorityError = nil
                }
            }
            .onChange(of: addInsurance) { _, enabled in
                if !enabled {
                    insNumberError = nil
                    insAuthorityError = nil
                }
            }
            .onChange(of: manufacturer) { _, newManufacturer in
                guard !newManufacturer.isEmpty else {
                    model = ""
                    return
                }

                let validModels = defaultVehiclePresets
                    .filter { $0.manufacturer == newManufacturer }
                    .map(\.model)
                if !validModels.contains(model) {
                    model = validModels.first ?? model
                }

                applyPresetSelectionIfNeeded()
            }
            .onChange(of: name) { _, newName in
                if vehicleNameOptions.contains(where: { $0.caseInsensitiveCompare(newName) == .orderedSame }) {
                    selectedNameOption = vehicleNameOptions.first(where: {
                        $0.caseInsensitiveCompare(newName) == .orderedSame
                    }) ?? newName
                } else if !newName.isEmpty {
                    selectedNameOption = "Custom"
                }
            }
            .onChange(of: manufacturer) { _, newManufacturer in
                if manufacturerOptions.contains(where: { $0.caseInsensitiveCompare(newManufacturer) == .orderedSame }) {
                    selectedManufacturerOption = manufacturerOptions.first(where: {
                        $0.caseInsensitiveCompare(newManufacturer) == .orderedSame
                    }) ?? newManufacturer
                } else if !newManufacturer.isEmpty {
                    selectedManufacturerOption = "Custom"
                }
            }
            .onChange(of: model) { _, _ in
                applyPresetSelectionIfNeeded()
            }
            .onChange(of: model) { _, newModel in
                if modelOptions.contains(where: { $0.caseInsensitiveCompare(newModel) == .orderedSame }) {
                    selectedModelOption = modelOptions.first(where: {
                        $0.caseInsensitiveCompare(newModel) == .orderedSame
                    }) ?? newModel
                } else if !newModel.isEmpty {
                    selectedModelOption = "Custom"
                }
            }
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
                .font(.subheadline)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.green, in: Capsule())
        .padding(.top, 8)
    }

    // MARK: - Submit

    private func submitForm() async {
        if let vinValidationError = vinValidationError(for: vin) {
            vinError = vinValidationError
            return
        }
        if let plateValidationError = licensePlateValidationError(for: licensePlate) {
            licensePlateError = plateValidationError
            return
        }
        if let customColorValidationError = colorValidationError(for: color) {
            colorError = customColorValidationError
            return
        }
        if addRegistration {
            if let registrationError = registrationNumberValidationError(for: regNumber) {
                regNumberError = registrationError
                return
            }
            if let authorityError = issuingAuthorityValidationError(for: regAuthority, fieldName: "Issuing authority") {
                regAuthorityError = authorityError
                return
            }
            if regExpiry < regIssued {
                regAuthorityError = "Registration expiry must be after issue date."
                return
            }
        }
        if addInsurance {
            if let policyError = insurancePolicyValidationError(for: insNumber) {
                insNumberError = policyError
                return
            }
            if let insurerError = issuingAuthorityValidationError(for: insAuthority, fieldName: "Insurer name") {
                insAuthorityError = insurerError
                return
            }
            if insExpiry < insIssued {
                insAuthorityError = "Insurance expiry must be after issue date."
                return
            }
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
        if defaultVehicleColors.contains(where: { $0.caseInsensitiveCompare(v.color) == .orderedSame }) {
            selectedColorOption = defaultVehicleColors.first(where: {
                $0.caseInsensitiveCompare(v.color) == .orderedSame
            }) ?? v.color
        } else {
            selectedColorOption = "Custom"
            colorError = colorValidationError(for: v.color)
        }
        if defaultVehiclePresets.contains(where: { $0.name.caseInsensitiveCompare(v.name) == .orderedSame }) {
            selectedNameOption = defaultVehiclePresets.first(where: {
                $0.name.caseInsensitiveCompare(v.name) == .orderedSame
            })?.name ?? v.name
        } else {
            selectedNameOption = "Custom"
        }
        if manufacturerOptions.contains(where: { $0.caseInsensitiveCompare(v.manufacturer) == .orderedSame }) {
            selectedManufacturerOption = manufacturerOptions.first(where: {
                $0.caseInsensitiveCompare(v.manufacturer) == .orderedSame
            }) ?? v.manufacturer
        } else {
            selectedManufacturerOption = "Custom"
        }
        if modelOptions.contains(where: { $0.caseInsensitiveCompare(v.model) == .orderedSame }) {
            selectedModelOption = modelOptions.first(where: {
                $0.caseInsensitiveCompare(v.model) == .orderedSame
            }) ?? v.model
        } else {
            selectedModelOption = "Custom"
        }
        fuelType     = v.fuelType
        seatingCapacity = v.seatingCapacity
    }

    private func applyPresetSelectionIfNeeded() {
        guard let preset = defaultVehiclePresets.first(where: {
            $0.manufacturer == manufacturer && $0.model == model
        }) else { return }
        if name.isEmpty || presetNames.contains(name) {
            name = preset.name
            selectedNameOption = preset.name
        }
    }

    @MainActor
    private func runValidationSelfTestsIfNeeded() {
        guard !didRunValidationSelfTests else { return }
        didRunValidationSelfTests = true
#if DEBUG
        let checks: [(String, Bool)] = [
            ("VIN required fallback",
             vinValidationError(for: "")?.contains("required") == true),
            ("VIN length fallback",
             vinValidationError(for: "MAT123")?.contains("17 characters") == true),
            ("VIN invalid-char fallback",
             vinValidationError(for: "MAT1234567890123@")?.contains("letters and numbers") == true),
            ("VIN forbidden-letter fallback",
             vinValidationError(for: "MATO2345678901234")?.contains("cannot contain I, O, or Q") == true),
            ("VIN WMI mismatch fallback",
             vinValidationError(for: "MA312345678901234", manufacturerOverride: "Tata")?.contains("WMI mismatch") == true),
            ("Plate required fallback",
             licensePlateValidationError(for: "")?.contains("required") == true),
            ("Plate >13 fallback",
             licensePlateValidationError(for: "MH12AB12345678")?.contains("longer than 13") == true),
            ("Plate format fallback",
             licensePlateValidationError(for: "M1-XX-1234")?.contains("Format must be") == true),
            ("Plate unique number fallback",
             licensePlateValidationError(for: "MH12AB0000")?.contains("0001 to 9999") == true),
            ("Valid plate accepted",
             licensePlateValidationError(for: "MH12AB1234") == nil),
            ("Registration standard format accepted",
             registrationNumberValidationError(for: "MH12AB1234") == nil),
            ("Registration BH format accepted",
             registrationNumberValidationError(for: "22 BH 1234 AB") == nil),
            ("Registration format fallback",
             registrationNumberValidationError(for: "INVALID123")?.contains("Invalid RC format") == true),
            ("Issuing authority fallback",
             issuingAuthorityValidationError(for: "RTO Mumbai", fieldName: "Issuing authority") == nil)
        ]

        for (name, pass) in checks {
            if pass {
                print("[AddVehicleView][ValidationSelfTest] PASS: \(name)")
            } else {
                print("[AddVehicleView][ValidationSelfTest] FAIL: \(name)")
            }
        }
#endif
    }
}

#Preview {
    AddVehicleView()
        .environment(AppDataStore.shared)
}
