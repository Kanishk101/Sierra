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
}
