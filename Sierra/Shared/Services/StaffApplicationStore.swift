import Foundation
import SwiftUI

/// Shared in-memory store for staff applications.
/// Both driver-side (submitted view) and admin-side (approval flow) read/write here.
@Observable
final class StaffApplicationStore {

    static let shared = StaffApplicationStore()

    var applications: [StaffApplication] = StaffApplication.samples

    var pendingCount: Int {
        applications.filter { $0.status == .pending }.count
    }

    private init() {}

    func application(for id: UUID) -> StaffApplication? {
        applications.first { $0.id == id }
    }

    func filtered(by status: ApprovalStatus) -> [StaffApplication] {
        applications.filter { $0.status == status }
    }

    /// Simulate adding a new application (called when driver submits profile).
    func addApplication(_ app: StaffApplication) {
        applications.insert(app, at: 0)
    }

    /// Approve a staff application.
    func approve(id: UUID) {
        guard let idx = applications.firstIndex(where: { $0.id == id }) else { return }
        applications[idx].status = .approved
        applications[idx].rejectionReason = nil

        // Update the actual AuthUser record so the staff member
        // transitions from PendingApprovalView → Dashboard on next login
        updateUserApproval(id: id, approved: true)

        // Simulated push notification
        let name = applications[idx].name
        print("\n🔔 PUSH NOTIFICATION ─────────────")
        print("To: \(applications[idx].email)")
        print("Title: Application Approved!")
        print("Body: Congratulations \(name)! Your FleetOS account has been approved. You can now sign in and start using the app.")
        print("──────────────────────────────────\n")
    }

    /// Reject a staff application with a reason.
    func reject(id: UUID, reason: String) {
        guard let idx = applications.firstIndex(where: { $0.id == id }) else { return }
        applications[idx].status = .rejected
        applications[idx].rejectionReason = reason

        let name = applications[idx].name
        print("\n🔔 PUSH NOTIFICATION ─────────────")
        print("To: \(applications[idx].email)")
        print("Title: Application Requires Attention")
        print("Body: Hi \(name), your FleetOS application needs revision. Reason: \(reason). Please contact your fleet administrator.")
        print("──────────────────────────────────\n")
    }

    // MARK: - Private

    /// Update the AuthUser record stored in Keychain.
    /// If the approved user is the currently logged-in user, also update AuthManager.
    private func updateUserApproval(id: UUID, approved: Bool) {
        // Check if this is the current logged-in user
        if var currentUser = AuthManager.shared.currentUser, currentUser.id == id {
            currentUser.isApproved = approved
            AuthManager.shared.currentUser = currentUser
            _ = KeychainService.save(currentUser, forKey: "com.fleetOS.currentUser")
        }
    }
}
