import Foundation

// MARK: - AddVehicleViewModel
// @MainActor @Observable — extracted from AddVehicleView (Phase 13 MVVM refactor).
// Contains all form state, validation logic, submission logic, and preset data.
// Store is injected via method parameters, not init.

@MainActor
@Observable
final class AddVehicleViewModel {

    // MARK: - Vehicle Form Fields

    var name = ""
    var manufacturer = ""
    var model = ""
    var selectedNameOption = ""
    var selectedManufacturerOption = ""
    var selectedModelOption = ""
    var year = 2025
    var vin = ""
    var licensePlate = ""
    var color = ""
    var selectedColorOption = ""
    var fuelType: FuelType = .diesel
    var seatingCapacity = 3

    // MARK: - Document Form State (add mode only)

    var addRegistration = false
    var regNumber = ""
    var regIssued = Date()
    var regExpiry = Date().addingTimeInterval(86400 * 365)
    var regAuthority = ""

    var addInsurance = false
    var insNumber = ""
    var insIssued = Date()
    var insExpiry = Date().addingTimeInterval(86400 * 365)
    var insAuthority = ""

    // MARK: - UI / Submission State

    var showSuccess = false
    var isSubmitting = false
    var vinError: String?
    var licensePlateError: String?
    var colorError: String?
    var regNumberError: String?
    var regAuthorityError: String?
    var insNumberError: String?
    var insAuthorityError: String?
    var errorMessage: String?
    var showError = false
    var didRunValidationSelfTests = false

    // MARK: - Edit Mode

    let editingVehicle: Vehicle?
    var onSaved: (() -> Void)?

    var isEditing: Bool { editingVehicle != nil }

    init(editingVehicle: Vehicle? = nil) {
        self.editingVehicle = editingVehicle
    }

    // MARK: - Preset Data

    struct VehiclePreset: Hashable {
        let name: String
        let manufacturer: String
        let model: String
    }

    let defaultVehicleColors: [String] = [
        "White", "Silver", "Gray", "Black", "Blue",
        "Red", "Brown", "Green", "Yellow", "Orange"
    ]

    let defaultVehiclePresets: [VehiclePreset] = [
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

    // MARK: - Computed Options

    var colorOptions: [String] {
        var options = defaultVehicleColors
        let trimmedColor = color.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedColor.isEmpty && !options.contains(where: { $0.caseInsensitiveCompare(trimmedColor) == .orderedSame }) {
            options.append(trimmedColor)
        }
        return options
    }

    var manufacturerOptions: [String] {
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

    var modelOptions: [String] {
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

    var vehicleNameOptions: [String] {
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

    var presetNames: Set<String> {
        Set(defaultVehiclePresets.map(\.name))
    }

    // MARK: - Validation

    var isFormValid: Bool {
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

    func vinValidationError(for rawVIN: String, manufacturerOverride: String? = nil) -> String? {
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
        let yearCode = chars[9]
        guard allowedVinYearCodes.contains(yearCode) else {
            return "10th character (year code) is invalid."
        }
        for idx in [11, 12] {
            let c = chars[idx]
            if c.isLetter && !allowedVinMonthCodes.contains(c) {
                return "\(idx + 1)th character has invalid month code."
            }
        }
        return nil
    }

    func licensePlateValidationError(for rawPlate: String) -> String? {
        let trimmed = rawPlate.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return "License plate is required." }
        guard trimmed.count <= 13 else { return "License plate cannot be longer than 13 characters." }
        let normalized = trimmed.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
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

    func colorValidationError(for rawColor: String) -> String? {
        let trimmed = rawColor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Color is required." }
        guard trimmed.range(of: "^[A-Za-z ]+$", options: .regularExpression) != nil else {
            return "Color can contain only alphabets."
        }
        return nil
    }

    func registrationNumberValidationError(for rawNumber: String) -> String? {
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

    func issuingAuthorityValidationError(for rawAuthority: String, fieldName: String) -> String? {
        let trimmed = rawAuthority.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "\(fieldName) is required." }
        guard trimmed.count >= 3 else { return "\(fieldName) must be at least 3 characters." }
        guard trimmed.range(of: "^[A-Za-z .&()-]+$", options: .regularExpression) != nil else {
            return "\(fieldName) can contain only letters and common separators."
        }
        return nil
    }

    func insurancePolicyValidationError(for rawNumber: String) -> String? {
        let trimmed = rawNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return "Policy number is required." }
        guard trimmed.range(of: "^[A-Z0-9/-]{6,24}$", options: .regularExpression) != nil else {
            return "Policy number must be 6–24 characters (letters/digits/-/)."
        }
        return nil
    }

    // MARK: - Actions

    func submit(store: AppDataStore) async {
        // Run full validation
        if let vinErr = vinValidationError(for: vin) {
            vinError = vinErr; return
        }
        if let plateErr = licensePlateValidationError(for: licensePlate) {
            licensePlateError = plateErr; return
        }
        if let clrErr = colorValidationError(for: color) {
            colorError = clrErr; return
        }
        if addRegistration {
            if let regErr = registrationNumberValidationError(for: regNumber) {
                regNumberError = regErr; return
            }
            if let authErr = issuingAuthorityValidationError(for: regAuthority, fieldName: "Issuing authority") {
                regAuthorityError = authErr; return
            }
            if regExpiry < regIssued {
                regAuthorityError = "Registration expiry must be after issue date."; return
            }
        }
        if addInsurance {
            if let polErr = insurancePolicyValidationError(for: insNumber) {
                insNumberError = polErr; return
            }
            if let insErr = issuingAuthorityValidationError(for: insAuthority, fieldName: "Insurer name") {
                insAuthorityError = insErr; return
            }
            if insExpiry < insIssued {
                insAuthorityError = "Insurance expiry must be after issue date."; return
            }
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            do {
                _ = try await SupabaseManager.ensureValidSession()
            } catch {
                if SupabaseManager.isSessionRecoveryError(error) {
                    errorMessage = "Your session expired. Please sign in again and retry."
                } else {
                    errorMessage = "Network unavailable. Please reconnect and retry."
                }
                showError = true
                return
            }

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

            showSuccess = true
            onSaved?()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Prefill / Preset Helpers

    func prefillIfEditing() {
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
        fuelType        = v.fuelType
        seatingCapacity = v.seatingCapacity
    }

    func applyPresetSelectionIfNeeded() {
        guard let preset = defaultVehiclePresets.first(where: {
            $0.manufacturer == manufacturer && $0.model == model
        }) else { return }
        if name.isEmpty || presetNames.contains(name) {
            name = preset.name
            selectedNameOption = preset.name
        }
    }

    func runValidationSelfTestsIfNeeded() {
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
                print("[AddVehicleViewModel][ValidationSelfTest] PASS: \(name)")
            } else {
                print("[AddVehicleViewModel][ValidationSelfTest] FAIL: \(name)")
            }
        }
        #endif
    }
}
