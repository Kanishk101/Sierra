import Foundation
import Supabase

/// ViewModel for the driver ad-hoc maintenance request form.
/// Supports sequential photo upload to Supabase Storage.
/// Photos are uploaded and their URLs stored on the vehicle_inspections
/// row (via photo_urls) when sourceInspectionId is set. The maintenance_tasks
/// table has no photo_urls column — photos link to the task via source_inspection_id.
@Observable
final class DriverMaintenanceRequestViewModel {

    // MARK: - Pre-filled context

    let vehicleId: UUID
    let driverId: UUID
    var tripId: UUID?
    var sourceInspectionId: UUID?

    // MARK: - Form fields

    var title: String = ""
    var issueDescription: String = ""
    var priority: TaskPriority = .medium
    var photos: [Data] = []

    // MARK: - Submission state

    var isSubmitting = false
    var submitError: String? = nil
    var submitSuccess = false

    init(vehicleId: UUID, driverId: UUID, tripId: UUID? = nil, sourceInspectionId: UUID? = nil) {
        self.vehicleId = vehicleId
        self.driverId = driverId
        self.tripId = tripId
        self.sourceInspectionId = sourceInspectionId
    }

    // MARK: - Submit

    func submit() async {
        guard !title.isEmpty else {
            submitError = "Please enter a title for the issue."
            return
        }
        guard !issueDescription.isEmpty else {
            submitError = "Please describe the issue."
            return
        }

        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }

        do {
            // Upload photos SEQUENTIALLY to Supabase Storage.
            // URLs are stored on the vehicle_inspections row (photo_urls)
            // linked via sourceInspectionId — maintenance_tasks has no photo_urls column.
            var uploadedURLs: [String] = []
            for photo in photos {
                let url = try await uploadPhoto(photo)
                uploadedURLs.append(url)
            }

            // If we have a source inspection and uploaded photos, patch the inspection
            // photo_urls so the fleet manager can see them alongside the task.
            if let inspectionId = sourceInspectionId, !uploadedURLs.isEmpty {
                do {
                    try await supabase
                        .from("vehicle_inspections")
                        .update(["photo_urls": uploadedURLs])
                        .eq("id", value: inspectionId.uuidString)
                        .execute()
                } catch {
                    // Non-fatal: request creation should still proceed even if photo_urls patch fails.
                    print("[DriverMaintenanceRequest] Non-fatal photo_urls update failed: \(error)")
                }
            }

            try await MaintenanceTaskService.createDriverRequest(
                vehicleId: vehicleId,
                driverId: driverId,
                title: title,
                description: issueDescription,
                priority: priority,
                sourceInspectionId: sourceInspectionId
            )
            submitSuccess = true
        } catch {
            submitError = error.localizedDescription
        }
    }

    // MARK: - Photo Upload (sequential, one at a time)

    private func uploadPhoto(_ data: Data) async throws -> String {
        let path = "maintenance-photos/\(vehicleId.uuidString)/\(UUID().uuidString).jpg"
        try await supabase.storage
            .from("maintenance-photos")
            .upload(path, data: data, options: .init(contentType: "image/jpeg"))
        let url = try supabase.storage
            .from("maintenance-photos")
            .getPublicURL(path: path)
        return url.absoluteString
    }
}
