import Foundation
import SwiftUI

@Observable
final class StaffApprovalViewModel {

    private let store = StaffApplicationStore.shared

    var selectedFilter: ApprovalStatus = .pending
    var isProcessing: Bool = false
    var showRejectField: Bool = false
    var rejectionReason: String = ""

    var filteredApplications: [StaffApplication] {
        store.filtered(by: selectedFilter)
    }

    var pendingCount: Int {
        store.pendingCount
    }

    // MARK: - Approve

    @MainActor
    func approve(staffId: UUID) async {
        isProcessing = true
        try? await Task.sleep(for: .milliseconds(800))
        store.approve(id: staffId)
        isProcessing = false
    }

    // MARK: - Reject

    @MainActor
    func reject(staffId: UUID, reason: String) async {
        isProcessing = true
        try? await Task.sleep(for: .milliseconds(800))
        store.reject(id: staffId, reason: reason)
        isProcessing = false
        resetRejectState()
    }

    func resetRejectState() {
        showRejectField = false
        rejectionReason = ""
    }
}
