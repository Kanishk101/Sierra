import Foundation
import Combine
import SwiftUI

enum ActiveNavigationAlertState {
    case turnAhead
    case collisionAhead
    case arrivingSoon

    var title: String {
        switch self {
        case .turnAhead: return "Turn Ahead"
        case .collisionAhead: return "Collision Ahead"
        case .arrivingSoon: return "Arriving Soon"
        }
    }

    var subtitle: String {
        switch self {
        case .turnAhead: return "Turn right on next segment"
        case .collisionAhead: return "Slow down and keep safe distance"
        case .arrivingSoon: return "Prepare for delivery"
        }
    }

    var icon: String {
        switch self {
        case .turnAhead: return "arrow.turn.up.right"
        case .collisionAhead: return "exclamationmark.triangle.fill"
        case .arrivingSoon: return "checkmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .turnAhead: return .appOrange
        case .collisionAhead: return Color(red: 0.90, green: 0.22, blue: 0.18)
        case .arrivingSoon: return Color(red: 0.20, green: 0.75, blue: 0.35)
        }
    }

    var background: Color {
        switch self {
        case .turnAhead: return Color.appOrange.opacity(0.14)
        case .collisionAhead: return Color(red: 0.90, green: 0.22, blue: 0.18).opacity(0.18)
        case .arrivingSoon: return Color(red: 0.20, green: 0.75, blue: 0.35).opacity(0.18)
        }
    }
}

@MainActor
final class ActiveNavigationViewModel: ObservableObject {
    @Published var showEndTripModal = false
    @Published var currentDistance = 142
    @Published var timeRemaining = 150
    @Published var currentSpeed: Double = 65
    @Published var roadOffset: CGFloat = 0
    @Published var navAlert: ActiveNavigationAlertState = .turnAhead
    @Published var showReportIssueModal = false
    @Published var issueText = ""
    @Published var showIssueSentToast = false
    @Published var showDeliveryProofModal = false
    @Published var deliveryProofImageAttached = false
    @Published var receiverSignedDocAttached = false
    @Published var loadState: ScreenLoadState = .idle
    @Published var fallbackErrorMessage: String?

    var progress: Double {
        ((142 - Double(currentDistance)) / 142) * 100
    }

    var canSubmitDelivery: Bool {
        deliveryProofImageAttached && receiverSignedDocAttached
    }

    func load(trip: Trip) {
        loadState = .loading
        let failures = AppRuntimeTestCases.validateTrips([trip])
        if !failures.isEmpty {
            fallbackErrorMessage = "Navigation data check failed. Using fallback values."
        }
        loadState = .loaded
    }

    func animateRoad() {
        withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
            roadOffset = 170
        }
    }

    func tick() {
        if currentDistance > 0 {
            currentDistance = max(0, currentDistance - 2)
            timeRemaining = max(0, timeRemaining - 2)
            currentSpeed = 60 + Double.random(in: 0...20)
            updateNavigationAlertState()
        }
    }

    func updateNavigationAlertState() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if currentDistance <= 10 {
                navAlert = .arrivingSoon
            } else if Bool.random() && currentDistance % 14 == 0 {
                navAlert = .collisionAhead
            } else {
                navAlert = .turnAhead
            }
        }
    }

    func submitIssue() {
        let trimmed = issueText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        withAnimation(.spring(response: 0.3)) {
            showReportIssueModal = false
            issueText = ""
            showIssueSentToast = true
        }
    }

    func hideIssueToast() {
        withAnimation(.easeOut(duration: 0.25)) {
            showIssueSentToast = false
        }
    }

    func clearError() {
        fallbackErrorMessage = nil
    }
}
