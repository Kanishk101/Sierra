import Foundation
import Combine
import SwiftUI

@MainActor
final class PreTripInspectionViewModel: ObservableObject {
    @Published var currentStep: InspectionStep = .checklist
    @Published var items: [InspectionItem] = [
        InspectionItem(name: "Brakes", icon: "circle.circle.fill"),
        InspectionItem(name: "Tyres", icon: "sun.max.fill"),
        InspectionItem(name: "Lights (Front)", icon: "lightbulb.fill"),
        InspectionItem(name: "Lights (Rear)", icon: "lightbulb.fill"),
        InspectionItem(name: "Horn", icon: "speaker.wave.2.fill"),
        InspectionItem(name: "Wipers", icon: "car.fill"),
        InspectionItem(name: "Mirrors", icon: "rectangle.split.2x1.fill"),
        InspectionItem(name: "Fuel Levels", icon: "fuelpump.fill"),
        InspectionItem(name: "Engine Oil", icon: "drop.fill"),
        InspectionItem(name: "Coolant", icon: "thermometer.medium"),
        InspectionItem(name: "Steering", icon: "steeringwheel"),
        InspectionItem(name: "Seat Belt", icon: "figure.seated.seatbelt"),
        InspectionItem(name: "Dashboard Warning Lights", icon: "exclamationmark.triangle.fill")
    ]

    @Published var fuelPhotoTaken = false
    @Published var odometerPhotoTaken = false
    @Published var defectPhotoPrimaryTaken = false
    @Published var defectPhotoSecondaryTaken = false
    @Published var requiresVehicleChange = false

    @Published var signatureLines: [[CGPoint]] = []
    @Published var currentLine: [CGPoint] = []
    @Published var hasSigned = false

    @Published var showCompletion = false
    @Published var showVehicleChangeRequested = false
    @Published var showMaintenanceRequestModal = false
    @Published var showMaintenanceRequestToast = false
    @Published var maintenanceRequestText = ""
    @Published var maintenanceProofImageAttached = false
    @Published var maintenanceRequestCreated = false

    @Published var loadState: ScreenLoadState = .idle
    @Published var fallbackErrorMessage: String?

    func load() {
        loadState = .loading
        if items.isEmpty {
            fallbackErrorMessage = "Inspection checklist failed to load. Showing fallback."
            items = [InspectionItem(name: "Brakes", icon: "circle.circle.fill")]
        }
        loadState = .loaded
    }

    var hasWarnItems: Bool {
        items.contains { !$0.isOk && $0.issueStatus == .warn }
    }

    var hasFailItems: Bool {
        items.contains { !$0.isOk && $0.issueStatus == .fail }
    }

    var hasUploadedProofImages: Bool {
        if requiresVehicleChange {
            return defectPhotoPrimaryTaken && defectPhotoSecondaryTaken
        }
        return fuelPhotoTaken && odometerPhotoTaken
    }

    var failedItemNames: [String] {
        items
            .filter { !$0.isOk && $0.issueStatus == .fail }
            .map(\.name)
    }

    func goBack(mode: InspectionMode) -> Bool {
        if currentStep == .checklist {
            return true
        }
        if mode == .postTrip {
            currentStep = .checklist
        } else {
            currentStep = InspectionStep(rawValue: currentStep.rawValue - 1) ?? .checklist
        }
        return false
    }

    func advanceStep(mode: InspectionMode) {
        if mode == .postTrip, currentStep == .checklist {
            currentStep = .signature
        } else {
            currentStep = InspectionStep(rawValue: currentStep.rawValue + 1) ?? .signature
        }
    }

    func sendWarnAlert(mode: InspectionMode) {
        advanceStep(mode: mode)
    }

    func sendFailAlert(mode: InspectionMode) {
        if mode == .postTrip {
            showMaintenanceRequestModal = true
            return
        }
        defectPhotoPrimaryTaken = false
        defectPhotoSecondaryTaken = false
        requiresVehicleChange = true
        advanceStep(mode: mode)
    }

    func submitVehicleChangeProof() {
        showVehicleChangeRequested = true
    }

    func completeInspection() {
        showCompletion = true
    }

    func submitMaintenanceRequest(mode: InspectionMode) {
        let trimmed = maintenanceRequestText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        maintenanceRequestCreated = true
        showMaintenanceRequestModal = false
        maintenanceRequestText = ""
        maintenanceProofImageAttached = false
        showMaintenanceRequestToast = true
        if mode == .postTrip, currentStep == .checklist {
            advanceStep(mode: mode)
        }
    }

    func hideMaintenanceToast() {
        showMaintenanceRequestToast = false
    }

    func clearError() {
        fallbackErrorMessage = nil
    }
}
