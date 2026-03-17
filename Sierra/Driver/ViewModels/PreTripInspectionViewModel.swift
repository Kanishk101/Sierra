import SwiftUI
import PhotosUI
import Supabase

// MARK: - Inspection Check Item (local UI state)

struct InspectionCheckItem: Identifiable {
    let id = UUID()
    var name: String
    var category: InspectionCategory
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

    // MARK: - State

    var currentStep = 1           // 1 = checklist, 2 = photos, 3 = summary
    var isSubmitting = false
    var submitError: String?
    var didSubmitSuccessfully = false

    // Step 1 — Checklist
    var checkItems: [InspectionCheckItem] = PreTripInspectionViewModel.defaultCheckItems()

    // Step 2 — Photos
    var selectedPhotoItems: [PhotosPickerItem] = []
    var photoData: [Data] = []
    var uploadedPhotoUrls: [String] = []
    var isUploadingPhotos = false
    var uploadProgress: String = ""

    // Step 3 — Computed
    var overallResult: InspectionResult {
        let hasFail = checkItems.contains { $0.result == .failed }
        let hasWarning = checkItems.contains { $0.result == .passedWithWarnings }
        if hasFail { return .failed }
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

    init(tripId: UUID, vehicleId: UUID, driverId: UUID, inspectionType: InspectionType = .preTripInspection) {
        self.tripId = tripId
        self.vehicleId = vehicleId
        self.driverId = driverId
        self.inspectionType = inspectionType
    }

    // MARK: - Default Check Items

    static func defaultCheckItems() -> [InspectionCheckItem] {
        [
            InspectionCheckItem(name: "Brakes", category: .safety),
            InspectionCheckItem(name: "Tyres", category: .tyres),
            InspectionCheckItem(name: "Lights (Front)", category: .lights),
            InspectionCheckItem(name: "Lights (Rear)", category: .lights),
            InspectionCheckItem(name: "Horn", category: .safety),
            InspectionCheckItem(name: "Wipers", category: .body),
            InspectionCheckItem(name: "Mirrors", category: .body),
            InspectionCheckItem(name: "Fuel Level", category: .fluids),
            InspectionCheckItem(name: "Engine Oil", category: .engine),
            InspectionCheckItem(name: "Coolant", category: .fluids),
            InspectionCheckItem(name: "Steering", category: .safety),
            InspectionCheckItem(name: "Seatbelt", category: .safety),
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

    // MARK: - Photo Upload (sequential per Safeguard 1)

    func uploadPhotos() async {
        isUploadingPhotos = true
        uploadedPhotoUrls = []
        let prefix = inspectionType == .preTripInspection ? "pre-trip" : "post-trip"

        for (index, data) in photoData.enumerated() {
            uploadProgress = "Uploading photo \(index + 1) of \(photoData.count)..."
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
                print("[InspectionVM] Photo \(index) failed to upload: \(error)")
                // Continue — partial upload is acceptable
            }
        }
        isUploadingPhotos = false
        uploadProgress = ""
    }

    // MARK: - Submit (Safeguard 2: insert inspection THEN update trip)

    func submitInspection(store: AppDataStore) async {
        isSubmitting = true
        submitError = nil

        do {
            // 1. Upload photos if any
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

            let defectsText = failedItems.isEmpty ? nil : failedItems.map(\.name).joined(separator: ", ")
            let isDefectRaised = overallResult == .failed

            // 3. INSERT inspection row with all data including photo_urls
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

            // 4. Update trip's inspection ID (AFTER insert succeeds — Safeguard 2)
            if let idx = store.trips.firstIndex(where: { $0.id == tripId }) {
                if inspectionType == .preTripInspection {
                    store.trips[idx].preInspectionId = inspection.id
                } else {
                    store.trips[idx].postInspectionId = inspection.id
                }
                try await TripService.updateTrip(store.trips[idx])
            }

            // 5. If failed, create maintenance task
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
            print("[InspectionVM] Submit failed: \(error)")
        }

        isSubmitting = false
    }
}
