import Foundation
import SwiftUI

@Observable
final class StaffApprovalViewModel {

    private let store = AppDataStore.shared

    var selectedFilter: ApprovalStatus = .pending
    var isProcessing: Bool = false
    var showRejectField: Bool = false
    var rejectionReason: String = ""

    var filteredApplications: [StaffApplication] {
        store.staffApplications.filter { $0.status == selectedFilter }
    }

    var pendingCount: Int {
        store.staffApplications.filter { $0.status == .pending }.count
    }

    // MARK: - Approve

    @MainActor
    func approve(staffId: UUID) async {
        isProcessing = true
        do {
            try await store.approveStaffApplication(applicationId: staffId)
        } catch {
            // surface error if needed — caller can observe isProcessing returning false
        }
        isProcessing = false
    }

    // MARK: - Reject

    @MainActor
    func reject(staffId: UUID, reason: String) async {
        isProcessing = true
        do {
            try await store.rejectStaffApplication(applicationId: staffId, reason: reason)
        } catch {
            // surface error if needed
        }
        isProcessing = false
        resetRejectState()
    }

    func resetRejectState() {
        showRejectField = false
        rejectionReason = ""
    }
}
