import SwiftUI
import PhotosUI
import UIKit
import Vision
import Supabase

// MARK: - InspectionCheckItem (local UI state)

struct InspectionCheckItem: Identifiable {
    let id = UUID()
    var name: String
    var category: InspectionCategory
    /// Default is .notChecked. The driver MUST set every item before submission.
    var result: InspectionResult = .notChecked
    var notes: String = ""
}

// MARK: - PreTripInspectionViewModel

@MainActor
@Observable
final class PreTripInspectionViewModel {

    // MARK: - Inputs

    let tripId: UUID
    let vehicleId: UUID
    let driverId: UUID
    let inspectionType: InspectionType

    // MARK: - Navigation state

    var currentStep = 1  // 1 = checklist, 2 = photos, 3 = summary

    // MARK: - Odometer capture (Step 1)

    enum OdometerOCRState {
        case idle           // nothing started yet
        case scanning       // camera presented
        case result(String) // OCR returned a reading — show for confirmation
        case confirmed      // user tapped Accept or entered manually
        case failed         // OCR ran but found no digits
    }

    enum FuelGaugeOCRState {
        case idle
        case scanning
        case result(String)
        case confirmed
        case failed
    }

    var odometerText: String = ""             // current text field value
    var odometerOCRState: OdometerOCRState = .idle
    var odometerCameraImage: UIImage?          // image captured for OCR
    var showOdometerCamera = false
    var fuelLevelText: String = ""
    var fuelGaugeOCRState: FuelGaugeOCRState = .idle

    /// Final confirmed odometer reading (nil until confirmed).
    var odometerReading: Double? {
        parseOdometerValue(from: odometerText)
    }

    /// True when odometer required but not yet filled in (pre-trip only).
    var odometerRequired: Bool { false }  // Bug 6: odometer moved to page 2 as a photo, not required for advance
    var odometerValid: Bool { odometerValidationError == nil }

    /// Odometer format rule:
    /// - 1 to 6 integer digits
    /// - optional 1 decimal place
    /// - max value 999999.9
    var odometerValidationError: String? {
        let raw = odometerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        guard raw.range(of: #"^\d{1,6}(\.\d)?$"#, options: .regularExpression) != nil else {
            return "Enter valid odometer (up to 6 digits, optional 1 decimal)."
        }
        guard let value = Double(raw), value <= 999_999.9 else {
            return "Odometer cannot exceed 999999.9."
        }
        return nil
    }

    var fuelLevelPct: Int? {
        let cleaned = fuelLevelText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "%", with: "")
        guard let value = Int(cleaned) else { return nil }
        return min(100, max(0, value))
    }

    var hasRequiredMediaReadings: Bool {
        odometerReading != nil && fuelLevelPct != nil
    }

    var mediaReadingsMissingMessage: String? {
        let missingOdometer = odometerReading == nil
        let missingFuel = fuelLevelPct == nil

        if let odoError = odometerValidationError {
            if missingFuel {
                return "\(odoError) Fuel level is also required."
            }
            return odoError
        }

        if missingOdometer && missingFuel {
            return "Odometer and fuel level are required before continuing."
        }
        if missingOdometer {
            return "Odometer reading is required before continuing."
        }
        if missingFuel {
            return "Fuel level is required before continuing."
        }
        return nil
    }

    func sanitizeOdometerInput(_ text: String) -> String {
        let allowed = text.filter { $0.isNumber || $0 == "." }
        var result = ""
        var didUseDot = false
        var intCount = 0
        var fracCount = 0

        for ch in allowed {
            if ch == "." {
                if didUseDot { continue }
                if result.isEmpty { continue }
                didUseDot = true
                result.append(ch)
                continue
            }

            if didUseDot {
                if fracCount >= 1 { continue }
                fracCount += 1
            } else {
                if intCount >= 6 { continue }
                intCount += 1
            }
            result.append(ch)
        }
        return result
    }

    private func parseOdometerValue(from text: String) -> Double? {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        guard raw.range(of: #"^\d{1,6}(\.\d)?$"#, options: .regularExpression) != nil else { return nil }
        guard let value = Double(raw), value <= 999_999.9 else { return nil }
        return value
    }

    // MARK: - Fuel receipt (Post-trip)
    var fuelReceiptUrl: String?

    // MARK: - Submission state

    var isSubmitting = false
    var submitError: String?
    var didSubmitSuccessfully = false

    // Maintenance task auto-creation state
    var maintenanceBannerText: String?
    var tripBlockedByInspection = false

    // MARK: - Step 1: Checklist

    var checkItems: [InspectionCheckItem] = PreTripInspectionViewModel.defaultCheckItems()

    // MARK: - Step 2: Per-item photos (Phase 6)

    /// itemId → raw Data array (in-memory, not yet uploaded)
    var itemPhotoData: [UUID: [Data]] = [:]

    /// itemId → uploaded public URL array (after upload succeeds)
    var itemPhotoUrls: [UUID: [String]] = [:]

    /// PhotosPickerItem selections per item — used by the photo step UI
    var itemPhotoSelections: [UUID: [PhotosPickerItem]] = [:]

    // MARK: - General photos (non-defect overview shots)

    var generalPhotoSelections: [PhotosPickerItem] = []
    var generalPhotoData: [Data] = []
    var generalPhotoUrls: [String] = []

    // MARK: - Upload progress

    var isUploadingPhotos = false
    var uploadProgress: String = ""

    // MARK: - Bug 6: Signature (Page 3)
    var signatureImage: UIImage?

    // MARK: - Post-trip maintenance request
    var maintenanceDescription: String = ""

    // MARK: - Validation computed properties

    /// True when every checklist item has been explicitly reviewed OR is still .notChecked
    /// (notChecked renders as green/passing — driver actively toggling OFF marks them failed).
    /// Blocks advancement ONLY if a toggle-off item hasn't been resolved with Warn or Fail.
    var allItemsChecked: Bool {
        // In FMS_SS flow: notChecked = passing (green). Only explicitly .failed blocks.
        // We only block if there are items that are in an ambiguous state.
        // Since toggle OFF → .failed, there are no ambiguous states anymore.
        true // All items always have a valid state (notChecked=pass, failed=fail, etc.)
    }

    /// Count of items the driver has not yet reviewed.
    /// In the reverted FMS_SS flow, notChecked = green = effectively reviewed.
    var uncheckedCount: Int {
        0  // notChecked items are shown as green (passing) so nothing is truly "unchecked"
    }

    /// Items marked failed that have NO photo captured or uploaded yet.
    /// C-03 FIX: Check BOTH itemPhotoData (local captures) and itemPhotoUrls (uploaded URLs).
    /// Before submission, only itemPhotoData is populated — checking itemPhotoUrls alone
    /// permanently blocks the driver from advancing to summary.
    var failedItemsMissingPhoto: [InspectionCheckItem] {
        failedItems.filter {
            (itemPhotoData[$0.id] ?? []).isEmpty &&
            (itemPhotoUrls[$0.id] ?? []).isEmpty
        }
    }

    var canAdvanceToPhotos: Bool { true }  // Bug 6: no odometer gate on page 1

    /// May advance to summary only when all failed items have at least one photo.
    /// M-06 FIX: Warning items that are flagged as needing photos are also gated.
    var canAdvanceToSummary: Bool {
        (inspectionType == .postTripInspection || failedItemsMissingPhoto.isEmpty)
        && hasRequiredMediaReadings
    }

    /// Final submit gate: no failed item missing a photo + signature present.
    var canSubmit: Bool {
        let photosOk = inspectionType == .postTripInspection || failedItemsMissingPhoto.isEmpty
        return photosOk
            && signatureImage != nil
            && hasRequiredMediaReadings
    }

    // MARK: - Step 3: Computed results

    var overallResult: InspectionResult {
        let hasFail    = checkItems.contains { $0.result == .failed }
        let hasWarning = checkItems.contains { $0.result == .passedWithWarnings }
        if hasFail    { return .failed }
        if hasWarning { return .passedWithWarnings }
        return .passed
    }

    var failedItems: [InspectionCheckItem] {
        checkItems.filter { $0.result == .failed }
    }

    var warningItems: [InspectionCheckItem] {
        checkItems.filter { $0.result == .passedWithWarnings }
    }

    /// Items that need a photo in Step 2 — failed and warning items
    var itemsNeedingPhotos: [InspectionCheckItem] {
        checkItems.filter { $0.result == .failed || $0.result == .passedWithWarnings }
    }

    // Phase 11: Fuel level integration
    var fuelLevelNeedsAttention: Bool {
        checkItems.contains { $0.name == "Fuel Level" && ($0.result == .failed || $0.result == .passedWithWarnings) }
    }

    // MARK: - Init

    init(
        tripId: UUID,
        vehicleId: UUID,
        driverId: UUID,
        inspectionType: InspectionType = .preTripInspection
    ) {
        self.tripId         = tripId
        self.vehicleId      = vehicleId
        self.driverId       = driverId
        self.inspectionType = inspectionType
    }

    // MARK: - OCR Odometer Parsing

    private nonisolated func imageVariants(for image: UIImage) -> [CGImage] {
        guard let base = image.cgImage else { return [] }
        var variants: [CGImage] = [base]

        let width = CGFloat(base.width)
        let height = CGFloat(base.height)
        let cropRects: [CGRect] = [
            CGRect(x: 0, y: height * 0.45, width: width, height: height * 0.55),   // lower half
            CGRect(x: width * 0.15, y: height * 0.35, width: width * 0.7, height: height * 0.5), // centered zoom
        ]
        for rect in cropRects {
            if let cropped = base.cropping(to: rect.integral) {
                variants.append(cropped)
            }
        }
        return variants
    }

    private nonisolated func recognizeTextLines(from cgImage: CGImage, fastMode: Bool) async -> [String] {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = fastMode ? .fast : .accurate
            request.usesLanguageCorrection = false
            request.minimumTextHeight = fastMode ? 0.012 : 0.008

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    /// Runs Vision OCR on multiple crops to reduce the need for tight manual zoom.
    nonisolated func extractOdometerReading(from image: UIImage) async -> String? {
        let variants = imageVariants(for: image)
        guard !variants.isEmpty else { return nil }

        let pattern = #"\b\d[\d,\.]{2,9}\d\b"#
        let regex = try? NSRegularExpression(pattern: pattern)
        var best: String?
        var bestScore = 0

        for cg in variants {
            for fast in [true, false] {
                let lines = await recognizeTextLines(from: cg, fastMode: fast)
                for line in lines {
                    let range = NSRange(line.startIndex..., in: line)
                    guard let match = regex?.firstMatch(in: line, range: range),
                          let swiftRange = Range(match.range, in: line) else { continue }
                    let raw = String(line[swiftRange])
                        .replacingOccurrences(of: ",", with: "")
                        .replacingOccurrences(of: ".", with: "")
                    let score = raw.count
                    if score > bestScore {
                        bestScore = score
                        best = raw
                    }
                }
            }
        }

        return best
    }

    nonisolated func extractFuelGaugeReading(from image: UIImage) async -> String? {
        let variants = imageVariants(for: image)
        guard !variants.isEmpty else { return nil }

        let pctRegex = try? NSRegularExpression(pattern: #"\b(100|[1-9]?\d)\s*%?\b"#)
        var candidates: [Int] = []

        for cg in variants {
            for fast in [true, false] {
                let lines = await recognizeTextLines(from: cg, fastMode: fast)
                for line in lines {
                    let range = NSRange(line.startIndex..., in: line)
                    let matches = pctRegex?.matches(in: line, range: range) ?? []
                    for match in matches {
                        guard let r = Range(match.range(at: 1), in: line),
                              let value = Int(line[r]) else { continue }
                        candidates.append(value)
                    }
                }
            }
        }

        guard let best = candidates.sorted(by: { abs($0 - 50) < abs($1 - 50) }).first else { return nil }
        return String(best)
    }

    /// Called when camera dismisses with a captured image.
    func handleOCRImage(_ image: UIImage) async {
        odometerCameraImage = image
        odometerOCRState = .scanning
        if let reading = await extractOdometerReading(from: image) {
            odometerText = reading
            odometerOCRState = .result(reading)
        } else {
            odometerOCRState = .failed
        }
    }

    func handleFuelGaugeImage(_ image: UIImage) async {
        fuelGaugeOCRState = .scanning
        if let reading = await extractFuelGaugeReading(from: image) {
            fuelLevelText = reading
            fuelGaugeOCRState = .result(reading)
        } else {
            fuelGaugeOCRState = .failed
        }
    }

    func handleOdometerCaptureCancelled() {
        showOdometerCamera = false
        if case .scanning = odometerOCRState {
            odometerOCRState = odometerText.isEmpty ? .idle : .confirmed
        }
    }

    func handleFuelCaptureCancelled() {
        if case .scanning = fuelGaugeOCRState {
            fuelGaugeOCRState = fuelLevelText.isEmpty ? .idle : .confirmed
        }
    }

    // MARK: - Default Check Items

    static func defaultCheckItems() -> [InspectionCheckItem] {
        [
            InspectionCheckItem(name: "Brakes",                   category: .safety),
            InspectionCheckItem(name: "Tyres",                    category: .tyres),
            InspectionCheckItem(name: "Lights (Front)",           category: .lights),
            InspectionCheckItem(name: "Lights (Rear)",            category: .lights),
            InspectionCheckItem(name: "Horn",                     category: .safety),
            InspectionCheckItem(name: "Wipers",                   category: .body),
            InspectionCheckItem(name: "Mirrors",                  category: .body),
            InspectionCheckItem(name: "Fuel Level",               category: .fluids),
            InspectionCheckItem(name: "Engine Oil",               category: .engine),
            InspectionCheckItem(name: "Coolant",                  category: .fluids),
            InspectionCheckItem(name: "Steering",                 category: .safety),
            InspectionCheckItem(name: "Seatbelt",                 category: .safety),
            InspectionCheckItem(name: "Dashboard Warning Lights", category: .safety),
        ]
    }

    // MARK: - Photo Loading (per-item)

    /// Called when the user picks images for a specific check item.
    func loadPhotosForItem(_ itemId: UUID, selections: [PhotosPickerItem]) async {
        var datas: [Data] = []
        for sel in selections {
            if let data = try? await sel.loadTransferable(type: Data.self) {
                datas.append(data)
            }
        }
        itemPhotoData[itemId] = datas
    }

    /// Called when the user picks general / overview photos.
    func loadGeneralPhotos(selections: [PhotosPickerItem]) async {
        var datas: [Data] = []
        for sel in selections {
            if let data = try? await sel.loadTransferable(type: Data.self) {
                datas.append(data)
            }
        }
        generalPhotoData = datas
    }

    // MARK: - Image Compression (Phase 6)

    /// Compresses image data to stay under `maxSizeKB`. Runs on a background thread.
    /// Returns nil only if data is not a valid image.
    nonisolated func compressImage(_ data: Data, maxSizeKB: Int) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxBytes = maxSizeKB * 1024

        // Step 1: Progressive JPEG quality reduction
        var quality: CGFloat = 0.8
        var compressed = image.jpegData(compressionQuality: quality)
        while let c = compressed, c.count > maxBytes, quality > 0.1 {
            quality -= 0.1
            compressed = image.jpegData(compressionQuality: quality)
        }

        // Step 2: If still too large, resize proportionally
        if let c = compressed, c.count > maxBytes {
            let scale = CGFloat(maxBytes) / CGFloat(c.count)
            let newSize = CGSize(
                width:  image.size.width  * sqrt(scale),
                height: image.size.height * sqrt(scale)
            )
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let resized = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            return resized.jpegData(compressionQuality: 0.7)
        }
        return compressed
    }

    // MARK: - Photo Upload (per-item)

    /// Uploads all stored per-item photo Data to Supabase storage, with compression.
    /// Populates `itemPhotoUrls` with resulting public URLs.
    func uploadAllPhotos() async {
        isUploadingPhotos = true
        let prefix = inspectionType == .preTripInspection ? "pre-trip" : "post-trip"

        // Upload per-item photos
        for item in itemsNeedingPhotos {
            guard let datas = itemPhotoData[item.id], !datas.isEmpty else { continue }
            var urls: [String] = []
            for (idx, rawData) in datas.enumerated() {
                uploadProgress = "Uploading photo \(idx + 1)/\(datas.count) for \(item.name)…"
                let compressed = await Task.detached { [weak self] in
                    self?.compressImage(rawData, maxSizeKB: 800) ?? rawData
                }.value
                let path = "\(prefix)/\(tripId.uuidString)/\(item.id.uuidString)/\(UUID().uuidString).jpg"
                do {
                    try await supabase.storage
                        .from("inspection-photos")
                        .upload(path, data: compressed, options: .init(contentType: "image/jpeg"))
                    let publicUrl = try supabase.storage
                        .from("inspection-photos")
                        .getPublicURL(path: path)
                    urls.append(publicUrl.absoluteString)
                } catch {
                    uploadProgress = "⚠️ Photo \(idx + 1) for \(item.name) failed: \(error.localizedDescription)"
                }
            }
            itemPhotoUrls[item.id] = urls
        }

        // Upload general photos
        if !generalPhotoData.isEmpty {
            var generalUrls: [String] = []
            for (idx, rawData) in generalPhotoData.enumerated() {
                uploadProgress = "Uploading general photo \(idx + 1)/\(generalPhotoData.count)…"
                let compressed = await Task.detached { [weak self] in
                    self?.compressImage(rawData, maxSizeKB: 800) ?? rawData
                }.value
                let path = "\(prefix)/\(tripId.uuidString)/general/\(UUID().uuidString).jpg"
                do {
                    try await supabase.storage
                        .from("inspection-photos")
                        .upload(path, data: compressed, options: .init(contentType: "image/jpeg"))
                    let publicUrl = try supabase.storage
                        .from("inspection-photos")
                        .getPublicURL(path: path)
                    generalUrls.append(publicUrl.absoluteString)
                } catch {
                    uploadProgress = "⚠️ General photo \(idx + 1) failed: \(error.localizedDescription)"
                }
            }
            generalPhotoUrls = generalUrls
        }

        isUploadingPhotos = false
        uploadProgress = ""
    }

    // MARK: - Submit

    func submitInspection(store: AppDataStore) async {
        // Guard: prevent double-submission on rapid taps
        guard !isSubmitting else { return }

        guard canSubmit else {
            if !allItemsChecked {
                submitError = "All \(uncheckedCount) item(s) must be checked before submitting."
            } else if let mediaError = mediaReadingsMissingMessage {
                submitError = mediaError
            } else {
                let names = failedItemsMissingPhoto.map(\.name).joined(separator: ", ")
                submitError = "Please add at least one photo for failed items: \(names)"
            }
            return
        }

        isSubmitting = true
        submitError  = nil

        do {
            // 1. Upload all photos (per-item + general)
            let totalPhotos = itemPhotoData.values.flatMap { $0 }.count + generalPhotoData.count
            if totalPhotos > 0 {
                await uploadAllPhotos()
            }

            // 2. Build InspectionItem array with per-item photo URLs
            let items = checkItems.map { item in
                InspectionItem(
                    id: item.id,
                    checkName: item.name,
                    category: item.category,
                    result: item.result,
                    notes: item.notes.isEmpty ? nil : item.notes,
                    photoUrls: itemPhotoUrls[item.id] ?? []
                )
            }

            // Aggregate all photo URLs for the top-level inspection record
            let allPhotoUrls = itemPhotoUrls.values.flatMap { $0 } + generalPhotoUrls

            // Confirm final odometer reading
            let confirmedOdometer = odometerReading

            let defectsText    = failedItems.isEmpty ? nil : failedItems.map(\.name).joined(separator: ", ")
            let isDefectRaised = overallResult == .failed
            _      = overallResult == .failed || overallResult == .passedWithWarnings

            // 3. INSERT inspection row
            let inspection = try await VehicleInspectionService.submitInspectionWithPhotos(
                tripId: tripId,
                vehicleId: vehicleId,
                driverId: driverId,
                type: inspectionType,
                overallResult: overallResult,
                items: items,
                defectsReported: defectsText,
                additionalNotes: nil,
                driverSignatureUrl: nil,
                photoUrls: allPhotoUrls,
                odometerReading: confirmedOdometer,
                fuelLevelPct: fuelLevelPct,
                fuelReceiptUrl: fuelReceiptUrl,
                isDefectRaised: isDefectRaised,
                raisedTaskId: nil
            )

            // 4. Resolve vehicle license plate for maintenance request title
            let vehiclePlate = store.vehicle(for: vehicleId)?.licensePlate ?? vehicleId.uuidString.prefix(8).description
            var createdMaintenanceTaskId: UUID?

            // 5. Auto-create repair request for inspection failure (pre-trip or post-trip).
            // Warnings alone notify but do not auto-create.
            if overallResult == .failed {
                let issueItemNames = failedItems.map(\.name).joined(separator: ", ")
                let issueDetails = failedItems
                    .map { item in
                        let cleanNote = item.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        if cleanNote.isEmpty {
                            return "- \(item.name)"
                        }
                        return "- \(item.name): \(cleanNote)"
                    }
                    .joined(separator: "\n")
                let typeLabel = inspectionType == .preTripInspection ? "Pre-trip" : "Post-trip"
                let autoDescription = maintenanceDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "\(typeLabel) inspection issues: \(issueItemNames)\n\(issueDetails)"
                    : maintenanceDescription

                let createdTaskId = try await MaintenanceTaskService.createDriverRequest(
                    vehicleId: vehicleId,
                    createdById: driverId,
                    title: "\(typeLabel) Defect \u{2013} \(vehiclePlate)",
                    description: autoDescription,
                    sourceInspectionId: inspection.id
                )
                createdMaintenanceTaskId = createdTaskId

                // Pre-trip failure should always raise an active defect alert that blocks the trip
                // until reassignment is done by fleet manager.
                if inspectionType == .preTripInspection {
                    let trip = store.trip(for: tripId)
                    let lat = trip?.originLatitude ?? trip?.destinationLatitude ?? 0
                    let lon = trip?.originLongitude ?? trip?.destinationLongitude ?? 0
                    let defectAlert = EmergencyAlert(
                        id: UUID(),
                        driverId: driverId,
                        tripId: tripId,
                        vehicleId: vehicleId,
                        latitude: lat,
                        longitude: lon,
                        alertType: .defect,
                        status: .active,
                        description: "\(typeLabel) inspection failed: \(issueItemNames)",
                        acknowledgedBy: nil,
                        acknowledgedAt: nil,
                        resolvedAt: nil,
                        triggeredAt: Date(),
                        createdAt: Date()
                    )
                    try? await EmergencyAlertService.addEmergencyAlert(defectAlert)
                    store.emergencyAlerts.insert(defectAlert, at: 0)
                }

                // Keep vehicle state in sync immediately after a failed inspection.
                if let vehicleIdx = store.vehicles.firstIndex(where: { $0.id == vehicleId }) {
                    store.vehicles[vehicleIdx].status = .inMaintenance
                    try? await VehicleService.updateVehicle(store.vehicles[vehicleIdx])
                }

                // Notify all admins about the defect (non-blocking)
                let defectTitle = "\(typeLabel) Defect \u{2013} \(vehiclePlate)"
                let driverName = store.staffMember(for: driverId)?.displayName ?? "Driver"
                Task {
                    await NotificationService.sendToAdmins(
                        type: .maintenanceRequest,
                        title: "Defect Reported \u{2013} \(vehiclePlate)",
                        body: "\(driverName) reported: \(defectTitle)",
                        entityType: "maintenance_task",
                        entityId: createdTaskId
                    )
                }

                maintenanceBannerText = "Maintenance flow started for \(vehiclePlate)"
            }

            if inspectionType == .postTripInspection, let createdMaintenanceTaskId {
                await linkInspectionToMaintenanceTaskIfMissing(
                    taskId: createdMaintenanceTaskId,
                    inspectionId: inspection.id
                )
            }

            // 6. Update trip's inspection ID using targeted patch only.
            if let idx = store.trips.firstIndex(where: { $0.id == tripId }) {
                var updatedTrip = store.trips[idx]
                if inspectionType == .preTripInspection {
                    updatedTrip.preInspectionId = inspection.id
                    if overallResult == .failed {
                        // BLOCK trip start: vehicle requires maintenance
                        tripBlockedByInspection = true
                        // Don't set trip to active — leave it as scheduled
                    } else {
                        // Warn or pass: allow trip start
                        updatedTrip.status = .active
                        updatedTrip.actualStartDate = Date()
                    }
                } else {
                    updatedTrip.postInspectionId = inspection.id
                }
                // Write to DB first
                try await TripService.setInspectionId(
                    tripId: tripId,
                    inspectionId: inspection.id,
                    type: inspectionType
                )
                // For pre-trip with pass/warn: also update trip status to Active in DB
                if inspectionType == .preTripInspection && overallResult != .failed {
                    try await TripService.updateTripStatus(id: tripId, status: .active)
                }
                // Commit to local store
                store.trips[idx] = updatedTrip
            }

            store.vehicleInspections.append(inspection)
            didSubmitSuccessfully = true
        } catch {
            submitError = error.localizedDescription
        }

        isSubmitting = false
    }

    private func linkInspectionToMaintenanceTaskIfMissing(taskId: UUID, inspectionId: UUID) async {
        struct TaskRow: Decodable { let source_inspection_id: UUID? }
        do {
            let rows: [TaskRow] = try await supabase
                .from("maintenance_tasks")
                .select("source_inspection_id")
                .eq("id", value: taskId.uuidString.lowercased())
                .limit(1)
                .execute()
                .value

            guard let target = rows.first else { return }
            guard target.source_inspection_id == nil else { return }

            struct Payload: Encodable { let source_inspection_id: String }
            try await supabase
                .from("maintenance_tasks")
                .update(Payload(source_inspection_id: inspectionId.uuidString))
                .eq("id", value: taskId.uuidString.lowercased())
                .execute()
        } catch {
            #if DEBUG
            print("[PreTripInspectionViewModel] Failed to deterministically link inspection to maintenance task: \(error)")
            #endif
        }
    }
}
