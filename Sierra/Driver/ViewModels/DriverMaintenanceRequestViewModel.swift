import Foundation
import Supabase

/// ViewModel for the driver ad-hoc maintenance request form.
/// Supports sequential photo upload and submission via MaintenanceTaskService.
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
    var photoURLs: [String] = []

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
            // Upload photos SEQUENTIALLY — never async let / TaskGroup
            for photo in photos {
                let url = try await uploadPhoto(photo)
                photoURLs.append(url)
            }

            try await MaintenanceTaskService.createDriverRequest(
                vehicleId: vehicleId,
                driverId: driverId,
                title: title,
                description: issueDescription,
                priority: priority,
                photoURLs: photoURLs,
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
