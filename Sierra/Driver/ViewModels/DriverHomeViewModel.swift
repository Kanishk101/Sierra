import Foundation

/// ViewModel for DriverHomeView — manages availability toggle and trip context.
/// Extracted from DriverHomeView to follow MVVM pattern.
@Observable
final class DriverHomeViewModel {

    var isTogglingAvailability = false
    var error: String? = nil

    /// Toggle driver availability between Available ↔ Unavailable.
    func toggleAvailability(staffId: UUID, currentlyAvailable: Bool) async {
        isTogglingAvailability = true
        defer { isTogglingAvailability = false }
        do {
            // updateAvailability returns the DB-confirmed value
            let confirmed = try await StaffMemberService.updateAvailability(
                staffId: staffId,
                available: !currentlyAvailable
            )
            let expected = currentlyAvailable
                ? StaffAvailability.unavailable.rawValue
                : StaffAvailability.available.rawValue
            if confirmed != expected {
                self.error = "Availability mismatch (expected \(expected), got \(confirmed))."
            }
            // AppDataStore's staff_members realtime channel will propagate the change
        } catch {
            self.error = error.localizedDescription
        }
    }

    // CRITICAL: Never manually set vehicle status here.
    // Trip start/end triggers handle vehicle status automatically.
}
