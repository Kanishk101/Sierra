import Foundation
import SwiftUI

@Observable
final class StaffApprovalViewModel {

    private let store = AppDataStore.shared

    var selectedFilter: ApprovalStatus = .pending
    var isProcessing: Bool = false
    var showRejectField: Bool = false
    var rejectionReason: String = ""

    /// Set when approve/reject fails so callers can display the error.
    var errorMessage: String?

    var filteredApplications: [StaffApplication] {
        store.staffApplications.filter { $0.status == selectedFilter }
    }

    var pendingCount: Int {
        store.staffApplications.filter { $0.status == .pending }.count
    }

    // MARK: - Approve

    @MainActor
    func approve(applicationId: UUID) async {
        let adminId = AuthManager.shared.currentUser?.id ?? UUID()
        isProcessing  = true
        errorMessage  = nil
        do {
            try await store.approveStaffApplication(id: applicationId, reviewedBy: adminId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }

    // MARK: - Reject

    @MainActor
    func reject(applicationId: UUID, reason: String) async {
        let adminId = AuthManager.shared.currentUser?.id ?? UUID()
        isProcessing = true
        errorMessage = nil
        do {
            try await store.rejectStaffApplication(id: applicationId, reason: reason, reviewedBy: adminId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
        resetRejectState()
    }

    func resetRejectState() {
        showRejectField  = false
        rejectionReason  = ""
    }
}
