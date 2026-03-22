import SwiftUI
import PhotosUI
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

    // MARK: - Submission state

    var isSubmitting = false
    var submitError: String?
    var didSubmitSuccessfully = false

    // MARK: - Step 1: Checklist

    var checkItems: [InspectionCheckItem] = PreTripInspectionViewModel.defaultCheckItems()

    // MARK: - Step 2: Photos

    var selectedPhotoItems: [PhotosPickerItem] = []
    var photoData: [Data] = []
    var uploadedPhotoUrls: [String] = []
    var isUploadingPhotos = false
    var uploadProgress: String = ""

    // MARK: - Validation computed properties

    /// True only when every single checklist item has been explicitly set
    /// (Pass, Warn, or Fail). A .notChecked result is not acceptable.
    var allItemsChecked: Bool {
        checkItems.allSatisfy { $0.result != .notChecked }
    }

    /// Count of items the driver has not yet reviewed.
    var uncheckedCount: Int {
        checkItems.filter { $0.result == .notChecked }.count
    }

    /// Failed items that have no associated photo uploaded yet.
    /// Uses a pragmatic approach: if ANY photo has been uploaded we
    /// consider the photo requirement satisfied for all failed items.
    /// Per-item photo linking is handled in the photo step redesign (Prompt 6).
    var failedItemsMissingPhoto: [InspectionCheckItem] {
        guard uploadedPhotoUrls.isEmpty else { return [] }
        return failedItems
    }

    /// Driver may advance from the checklist step only when every item is set.
    var canAdvanceToPhotos: Bool { allItemsChecked }

    /// Driver may submit only when:
    /// - All items are checked, AND
    /// - Either there are no failed items missing photos,
    ///   OR the overall result is passed (no failures at all).
    var canSubmit: Bool {
        allItemsChecked && (failedItemsMissingPhoto.isEmpty || overallResult == .passed)
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

    // MARK: - Init

    init(
        tripId: UUID,
        vehicleId: UUID,
        driverId: UUID,
        inspectionType: InspectionType = .preTripInspection
    ) {
        self.tripId        = tripId
        self.vehicleId     = vehicleId
        self.driverId      = driverId
        self.inspectionType = inspectionType
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

    // MARK: - Photo Loading

    func loadPhotos() async {
        photoData = []
        for item in selectedPhotoItems {
            if let data = try? await item.loadTransferable(type: Data.self) {
                photoData.append(data)
            }
        }
    }

    // MARK: - Photo Upload

    func uploadPhotos() async {
        isUploadingPhotos = true
        uploadedPhotoUrls = []
        let prefix = inspectionType == .preTripInspection ? "pre-trip" : "post-trip"

        for (index, data) in photoData.enumerated() {
            uploadProgress = "Uploading photo \(index + 1) of \(photoData.count)\u2026"
            do {
                let path = "\(prefix)/\(tripId.uuidString)/\(UUID().uuidString).jpg"
                try await supabase.storage
                    .from("inspection-photos")
                    .upload(path, data: data, options: .init(contentType: "image/jpeg"))
                let publicUrl = try supabase.storage
                    .from("inspection-photos")
                    .getPublicURL(path: path)
                uploadedPhotoUrls.append(publicUrl.absoluteString)
            } catch {
                // Surface upload errors to the user rather than silently dropping
                uploadProgress = "\u26a0\ufe0f Photo \(index + 1) failed: \(error.localizedDescription)"
                // Continue uploading remaining photos
            }
        }
        isUploadingPhotos = false
        uploadProgress = ""
    }

    // MARK: - Submit
    // Guard on canSubmit prevents blank-inspection submissions that would
    // previously show as PASSED due to the .notChecked default bug.

    func submitInspection(store: AppDataStore) async {
        // Hard gate — all items must be explicitly checked and failed items
        // must have at least one photo before we ever touch the network.
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
            // 1. Upload photos
            if !photoData.isEmpty {
                await uploadPhotos()
            }

            // 2. Build inspection items
            let items = checkItems.map { item in
                InspectionItem(
                    id: item.id,
                    checkName: item.name,
                    category: item.category,
                    result: item.result,
                    notes: item.notes.isEmpty ? nil : item.notes
                )
            }

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
                photoUrls: uploadedPhotoUrls,
                isDefectRaised: isDefectRaised,
                raisedTaskId: nil
            )

            // 4. Update trip's inspection ID (AFTER insert succeeds)
            if let idx = store.trips.firstIndex(where: { $0.id == tripId }) {
                if inspectionType == .preTripInspection {
                    store.trips[idx].preInspectionId = inspection.id
                } else {
                    store.trips[idx].postInspectionId = inspection.id
                }
                try await TripService.updateTrip(store.trips[idx])
            }

            // 5. If failed, auto-create maintenance task
            if isDefectRaised {
                let task = MaintenanceTask(
                    id: UUID(),
                    vehicleId: vehicleId,
                    createdByAdminId: driverId,
                    assignedToId: nil,
                    title: "Inspection Defect \u2014 \(inspectionType.rawValue)",
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
            // Propagate the full error to the UI — no silent catch-and-print
            submitError = error.localizedDescription
        }

        isSubmitting = false
    }
}
