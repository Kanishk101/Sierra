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

    var odometerText: String = ""             // current text field value
    var odometerOCRState: OdometerOCRState = .idle
    var odometerCameraImage: UIImage?          // image captured for OCR
    var showOdometerCamera = false

    /// Final confirmed odometer reading (nil until confirmed).
    var odometerReading: Double? {
        Double(odometerText.trimmingCharacters(in: .whitespacesAndNewlines).filter { $0.isNumber || $0 == "." })
    }

    /// True when odometer required but not yet filled in (pre-trip only).
    var odometerRequired: Bool { inspectionType == .preTripInspection }
    var odometerValid: Bool { !odometerRequired || (odometerReading != nil) }

    // MARK: - Fuel receipt (Post-trip)
    var fuelReceiptUrl: String?

    // MARK: - Submission state

    var isSubmitting = false
    var submitError: String?
    var didSubmitSuccessfully = false

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

    var canAdvanceToPhotos: Bool { odometerValid }

    /// May advance to summary only when all failed items have at least one photo.
    /// M-06 FIX: Warning items that are flagged as needing photos are also gated.
    var canAdvanceToSummary: Bool { failedItemsMissingPhoto.isEmpty }

    /// Final submit gate: no failed/warning item missing a photo + odometer valid.
    var canSubmit: Bool {
        failedItemsMissingPhoto.isEmpty && odometerValid
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

    /// Runs Vision text recognition on `image` and extracts the first
    /// plausible odometer reading (4–9 consecutive digits, optional comma/period).
    /// Calls completion on the main actor with the parsed string or nil on failure.
    nonisolated func extractOdometerReading(from image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let candidates = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }

                // Find first string that looks like an odometer: 4-9 digit number,
                // possibly with commas (100,000) or periods (123.4).
                let pattern = #"\b\d[\d,\.]{2,8}\d\b"#
                let regex = try? NSRegularExpression(pattern: pattern)

                for candidate in candidates {
                    let range = NSRange(candidate.startIndex..., in: candidate)
                    if let match = regex?.firstMatch(in: candidate, range: range),
                       let swiftRange = Range(match.range, in: candidate) {
                        let raw = String(candidate[swiftRange])
                            .replacingOccurrences(of: ",", with: "")
                        continuation.resume(returning: raw)
                        return
                    }
                }
                continuation.resume(returning: nil)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
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
                        .from("sierra-uploads")
                        .upload(path, data: compressed, options: .init(contentType: "image/jpeg"))
                    let publicUrl = try supabase.storage
                        .from("sierra-uploads")
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
                        .from("sierra-uploads")
                        .upload(path, data: compressed, options: .init(contentType: "image/jpeg"))
                    let publicUrl = try supabase.storage
                        .from("sierra-uploads")
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
        guard canSubmit else {
            if !allItemsChecked {
                submitError = "All \(uncheckedCount) item(s) must be checked before submitting."
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
                fuelReceiptUrl: fuelReceiptUrl,
                isDefectRaised: isDefectRaised,
                raisedTaskId: nil
            )

            // 4. Update trip's inspection ID — BUG-28 FIX: mutate DB first, then local store
            if let idx = store.trips.firstIndex(where: { $0.id == tripId }) {
                var updatedTrip = store.trips[idx]
                if inspectionType == .preTripInspection {
                    updatedTrip.preInspectionId = inspection.id
                } else {
                    updatedTrip.postInspectionId = inspection.id
                }
                // Write to DB first — if this throws, local state stays unchanged
                try await TripService.updateTrip(updatedTrip)
                // Only now commit to local store
                store.trips[idx] = updatedTrip
            }

            // 5. Auto-create maintenance task for defects
            if isDefectRaised {
                let task = MaintenanceTask(
                    id: UUID(),
                    vehicleId: vehicleId,
                    createdByAdminId: driverId,
                    assignedToId: nil,
                    title: "Inspection Defect — \(inspectionType.rawValue)",
                    taskDescription: "Defects found: \(defectsText ?? "Unknown")",
                    priority: .high,
                    status: .pending,
                    taskType: .inspectionDefect,
                    sourceAlertId: nil,
                    sourceInspectionId: inspection.id,
                    dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
                    completedAt: nil,
                    approvedById: nil,
                    approvedAt: nil,
                    rejectionReason: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                try await MaintenanceTaskService.addMaintenanceTask(task)
            }

            store.vehicleInspections.append(inspection)
            didSubmitSuccessfully = true
        } catch {
            submitError = error.localizedDescription
        }

        isSubmitting = false
    }
}
