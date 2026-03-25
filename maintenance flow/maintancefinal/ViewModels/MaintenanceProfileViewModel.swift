import Foundation

/// Profile ViewModel — static data, no external dependencies.
@MainActor
@Observable
final class MaintenanceProfileViewModel {

    var phone: String = "+91 98765 43210"
    var address: String = "42 Andheri East, Mumbai - 400069"
    var emergencyContactName: String = "Priya Sharma"
    var emergencyContactPhone: String = "+91 98765 43210"
    var isSaving = false
    var errorMessage: String? = nil

    func saveProfile() {
        isSaving = true
        // Simulate a save
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isSaving = false
        }
    }
}
