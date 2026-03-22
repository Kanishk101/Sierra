import SwiftUI

// MARK: - Inspection Step
enum InspectionStep: Int, CaseIterable {
    case checklist = 0
    case uploads = 1
    case signature = 2

    var title: String {
        switch self {
        case .checklist: return "Vehicle Checklist"
        case .uploads:   return "Upload Photos"
        case .signature: return "Driver Signature"
        }
    }
}

// MARK: - Inspection Item
struct InspectionItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    var isOk: Bool = true
    var isExpanded: Bool = false
    var issueStatus: IssueStatus = .warn
    var issueDetails: String = ""
}

enum IssueStatus: String {
    case warn = "Warn"
    case fail = "Fail"
}

enum InspectionMode {
    case preTrip
    case postTrip
}

// MARK: - Pre-Trip Inspection View
struct PreTripInspectionView: View {
    @Environment(\.dismiss) private var dismiss
    var inspectionMode: InspectionMode = .preTrip
    var inspectionTitle: String = "Pre-Trip Inspection"
    var onInspectionCompleted: () -> Void = {}
    var onVehicleChangeRequested: () -> Void = {}
    @StateObject private var viewModel = PreTripInspectionViewModel()
    @State private var hasAppeared: Bool = false

    var body: some View {
        ZStack {
            Color.appSurface
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation bar
                HStack {
                    Button(action: { goBack() }) {
                        Image(systemName: viewModel.currentStep == .checklist ? "xmark" : "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.appTextPrimary)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color.appCardBg))
                            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                    }

                    Spacer()

                    Text(inspectionTitle)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)

                    Spacer()

                    // Invisible spacer for centering
                    Color.clear.frame(width: 38, height: 38)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Step Progress Indicator
                StepProgressBar(currentStep: viewModel.currentStep)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)

                if let fallback = viewModel.fallbackErrorMessage {
                    AppFallbackErrorBanner(
                        message: fallback,
                        onDismiss: { viewModel.clearError() }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                }

                // Content
                TabView(selection: $viewModel.currentStep) {
                    ChecklistStepView(items: $viewModel.items)
                        .tag(InspectionStep.checklist)

                    Group {
                        if viewModel.requiresVehicleChange {
                            DefectProofStepView(
                                failedItemNames: viewModel.failedItemNames,
                                defectPhotoPrimaryTaken: $viewModel.defectPhotoPrimaryTaken,
                                defectPhotoSecondaryTaken: $viewModel.defectPhotoSecondaryTaken
                            )
                        } else {
                            UploadsStepView(
                                fuelPhotoTaken: $viewModel.fuelPhotoTaken,
                                odometerPhotoTaken: $viewModel.odometerPhotoTaken
                            )
                        }
                    }
                    .tag(InspectionStep.uploads)

                    SignatureStepView(
                        signatureLines: $viewModel.signatureLines,
                        currentLine: $viewModel.currentLine,
                        hasSigned: $viewModel.hasSigned
                    )
                    .tag(InspectionStep.signature)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.currentStep)

                // Bottom Button
                BottomActionButton(
                    currentStep: viewModel.currentStep,
                    isPostTrip: inspectionMode == .postTrip,
                    hasWarnItems: viewModel.hasWarnItems,
                    hasFailItems: viewModel.hasFailItems,
                    requiresVehicleChange: viewModel.requiresVehicleChange,
                    hasUploadedProofImages: viewModel.hasUploadedProofImages,
                    hasSigned: viewModel.hasSigned,
                    maintenanceRequestCreated: viewModel.maintenanceRequestCreated,
                    onNext: { advanceStep() },
                    onSendWarnAlert: { sendWarnAlert() },
                    onSendFailAlert: { sendFailAlert() },
                    onSubmitVehicleChangeProof: { submitVehicleChangeProof() },
                    onCreateMaintenanceRequest: {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.showMaintenanceRequestModal = true
                        }
                    },
                    onComplete: { completeInspection() }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            // Completion overlay
            if viewModel.showCompletion {
                InspectionCompleteOverlay(onDismiss: {
                    onInspectionCompleted()
                    dismiss()
                })
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    .zIndex(300)
            }

            if viewModel.showVehicleChangeRequested {
                VehicleChangeRequestedOverlay(onDismiss: {
                    onVehicleChangeRequested()
                    dismiss()
                })
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
                .zIndex(310)
            }

            if viewModel.showMaintenanceRequestModal {
                MaintenanceRequestModal(
                    text: $viewModel.maintenanceRequestText,
                    proofImageAttached: $viewModel.maintenanceProofImageAttached,
                    onCancel: {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.showMaintenanceRequestModal = false
                            viewModel.maintenanceRequestText = ""
                            viewModel.maintenanceProofImageAttached = false
                        }
                    },
                    onSubmit: { submitMaintenanceRequest() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(320)
            }

            if viewModel.showMaintenanceRequestToast {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Maintenance request sent")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.appOrange))
                    .padding(.top, 54)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(330)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            viewModel.load()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    hasAppeared = true
                }
            }
        }
    }

    // MARK: - Navigation
    private func goBack() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        if viewModel.goBack(mode: inspectionMode) {
            dismiss()
        }
    }

    private func advanceStep() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            viewModel.advanceStep(mode: inspectionMode)
        }
    }

    private func sendWarnAlert() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        viewModel.sendWarnAlert(mode: inspectionMode)
    }

    private func sendFailAlert() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        withAnimation(.spring(response: 0.3)) {
            viewModel.sendFailAlert(mode: inspectionMode)
        }
    }

    private func submitVehicleChangeProof() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            viewModel.submitVehicleChangeProof()
        }
    }

    private func completeInspection() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            viewModel.completeInspection()
        }
    }

    private func submitMaintenanceRequest() {
        withAnimation(.spring(response: 0.3)) {
            viewModel.submitMaintenanceRequest(mode: inspectionMode)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.25)) {
                viewModel.hideMaintenanceToast()
            }
        }
    }
}

// MARK: - Step Progress Bar
struct StepProgressBar: View {
    let currentStep: InspectionStep

    var body: some View {
        HStack(spacing: 0) {
            ForEach(InspectionStep.allCases, id: \.rawValue) { step in
                // Dot
                ZStack {
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.appOrange : Color.appDivider)
                        .frame(width: 16, height: 16)

                    if step.rawValue < currentStep.rawValue {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.white)
                    }
                }
                .scaleEffect(step == currentStep ? 1.15 : 1.0)
                .animation(.spring(response: 0.35), value: currentStep)

                // Connecting line (not after last)
                if step.rawValue < InspectionStep.allCases.count - 1 {
                    Rectangle()
                        .fill(
                            step.rawValue < currentStep.rawValue
                                ? Color.appOrange
                                : Color.appDivider
                        )
                        .frame(height: 3)
                        .animation(.easeInOut(duration: 0.4), value: currentStep)
                }
            }
        }
    }
}

// MARK: - Step 1: Checklist
struct ChecklistStepView: View {
    @Binding var items: [InspectionItem]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    VStack(spacing: 0) {
                        // Main toggle row
                        HStack(spacing: 14) {
                            Image(systemName: item.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.appOrange)
                                .frame(width: 28)

                            Text(item.name)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(.appTextPrimary)

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { items[index].isOk },
                                set: { newValue in
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        items[index].isOk = newValue
                                        items[index].isExpanded = !newValue
                                    }
                                    let generator = UISelectionFeedbackGenerator()
                                    generator.selectionChanged()
                                }
                            ))
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                            .labelsHidden()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color.appCardBg)

                        // Expanded issue details (when toggled OFF)
                        if item.isExpanded && !item.isOk {
                            IssueDetailPanel(
                                status: Binding(
                                    get: { items[index].issueStatus },
                                    set: { items[index].issueStatus = $0 }
                                ),
                                details: Binding(
                                    get: { items[index].issueDetails },
                                    set: { items[index].issueDetails = $0 }
                                )
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }

                        // Divider
                        if index < items.count - 1 {
                            Divider()
                                .padding(.leading, 62)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.appCardBg)
                    .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.appDivider.opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Issue Detail Panel
struct IssueDetailPanel: View {
    @Binding var status: IssueStatus
    @Binding var details: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Status selector
            Text("Status")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.appTextPrimary)

            HStack(spacing: 12) {
                StatusButton(
                    label: "Warn",
                    color: Color.appOrange,
                    isSelected: status == .warn,
                    onTap: {
                        withAnimation(.spring(response: 0.3)) { status = .warn }
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                )

                StatusButton(
                    label: "Fail",
                    color: Color(red: 0.90, green: 0.22, blue: 0.18),
                    isSelected: status == .fail,
                    onTap: {
                        withAnimation(.spring(response: 0.3)) { status = .fail }
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                )
            }

            // Issue details text field
            Text("Issue Details")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.appTextPrimary)

            TextEditor(text: $details)
                .font(.system(size: 14, design: .rounded))
                .frame(minHeight: 80)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.appSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.appDivider, lineWidth: 1)
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.appCardBg)
    }
}

// MARK: - Status Button
struct StatusButton: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .white : color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(isSelected ? color : color.opacity(0.0))
                )
                .overlay(
                    Capsule()
                        .stroke(color, lineWidth: isSelected ? 0 : 2)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Step 2: Uploads
struct UploadsStepView: View {
    @Binding var fuelPhotoTaken: Bool
    @Binding var odometerPhotoTaken: Bool

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                PhotoUploadCard(
                    title: "Upload Fuel Status",
                    icon: "fuelpump.fill",
                    isTaken: $fuelPhotoTaken
                )

                PhotoUploadCard(
                    title: "Upload Odometer Readings",
                    icon: "steeringwheel",
                    isTaken: $odometerPhotoTaken
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Step 2 (Fail Flow): Defect Proof Uploads
struct DefectProofStepView: View {
    let failedItemNames: [String]
    @Binding var defectPhotoPrimaryTaken: Bool
    @Binding var defectPhotoSecondaryTaken: Bool

    private var primaryDefectTitle: String {
        if let first = failedItemNames.first {
            return "Upload \(first) Defect Proof"
        }
        return "Upload Defect Area Proof"
    }

    private var secondaryDefectTitle: String {
        if failedItemNames.count > 1 {
            return "Upload \(failedItemNames[1]) Defect Proof"
        }
        return "Upload Additional Defect Proof"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 0.90, green: 0.22, blue: 0.18))

                    Text("Upload photos of defected areas for proof")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 2)

                VStack(spacing: 16) {
                    PhotoUploadCard(
                        title: primaryDefectTitle,
                        icon: "wrench.and.screwdriver.fill",
                        isTaken: $defectPhotoPrimaryTaken
                    )

                    PhotoUploadCard(
                        title: secondaryDefectTitle,
                        icon: "camera.fill",
                        isTaken: $defectPhotoSecondaryTaken
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Photo Upload Card
struct PhotoUploadCard: View {
    let title: String
    let icon: String
    @Binding var isTaken: Bool
    @State private var isAnimating: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.appOrange)

                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
            }

            // Photo capture area
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isTaken.toggle()
                    isAnimating = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isAnimating = false
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isTaken ? Color.green.opacity(0.06) : Color.appSurface)
                        .frame(height: 130)

                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isTaken ? Color.green.opacity(0.4) : Color.appTextSecondary.opacity(0.3),
                            style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                        )
                        .frame(height: 130)

                    if isTaken {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
                                .scaleEffect(isAnimating ? 1.2 : 1.0)
                            Text("Photo Captured")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
                        }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "camera")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.appTextSecondary.opacity(0.5))
                            Text("Tap to capture")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.appTextSecondary.opacity(0.5))
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appCardBg)
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.appDivider.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Step 3: Signature
struct SignatureStepView: View {
    @Binding var signatureLines: [[CGPoint]]
    @Binding var currentLine: [CGPoint]
    @Binding var hasSigned: Bool

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Driver's Signature")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.appTextPrimary)

                        Spacer()

                        if hasSigned {
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    signatureLines = []
                                    currentLine = []
                                    hasSigned = false
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 12, weight: .bold))
                                    Text("Clear")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(.appOrange)
                            }
                        }
                    }

                    // Signature canvas
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.appSurface)
                            .frame(height: 180)

                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                Color.appTextSecondary.opacity(0.25),
                                style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                            )
                            .frame(height: 180)

                        // Drawn signature
                        Canvas { context, size in
                            for line in signatureLines {
                                var path = Path()
                                if let first = line.first {
                                    path.move(to: first)
                                    for point in line.dropFirst() {
                                        path.addLine(to: point)
                                    }
                                }
                                context.stroke(path, with: .color(.appTextPrimary), lineWidth: 2.5)
                            }
                            // Current line
                            var currentPath = Path()
                            if let first = currentLine.first {
                                currentPath.move(to: first)
                                for point in currentLine.dropFirst() {
                                    currentPath.addLine(to: point)
                                }
                            }
                            context.stroke(currentPath, with: .color(.appTextPrimary), lineWidth: 2.5)
                        }
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    currentLine.append(value.location)
                                    if !hasSigned { hasSigned = true }
                                }
                                .onEnded { _ in
                                    signatureLines.append(currentLine)
                                    currentLine = []
                                }
                        )

                        // Placeholder text when empty
                        if !hasSigned {
                            Text("Sign here")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.appTextSecondary.opacity(0.35))
                                .allowsHitTesting(false)
                        }
                    }

                    Text("Sign above to confirm inspection")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.appCardBg)
                        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.appDivider.opacity(0.5), lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Bottom Action Button
struct BottomActionButton: View {
    let currentStep: InspectionStep
    let isPostTrip: Bool
    let hasWarnItems: Bool
    let hasFailItems: Bool
    let requiresVehicleChange: Bool
    let hasUploadedProofImages: Bool
    let hasSigned: Bool
    let maintenanceRequestCreated: Bool
    let onNext: () -> Void
    let onSendWarnAlert: () -> Void
    let onSendFailAlert: () -> Void
    let onSubmitVehicleChangeProof: () -> Void
    let onCreateMaintenanceRequest: () -> Void
    let onComplete: () -> Void

    var body: some View {
        Group {
            switch currentStep {
            case .checklist:
                if hasFailItems {
                    if isPostTrip {
                        ActionButton(
                            label: "Create Maintenance Request",
                            icon: "wrench.and.screwdriver.fill",
                            bgColor: Color(red: 0.90, green: 0.22, blue: 0.18),
                            action: onCreateMaintenanceRequest
                        )
                    } else {
                        ActionButton(
                            label: "Change Vehicle Alert",
                            icon: "exclamationmark.triangle.fill",
                            bgColor: Color(red: 0.90, green: 0.22, blue: 0.18),
                            action: onSendFailAlert
                        )
                    }
                } else if hasWarnItems {
                    ActionButton(
                        label: "Send Alert to Fleet Manager",
                        icon: "exclamationmark.bubble.fill",
                        bgColor: Color(red: 0.90, green: 0.22, blue: 0.18),
                        action: onSendWarnAlert
                    )
                } else {
                    ActionButton(
                        label: "Next",
                        icon: "arrow.right",
                        bgColor: .appOrange,
                        action: onNext
                    )
                }

            case .uploads:
                if requiresVehicleChange {
                    ActionButton(
                        label: "Send Proof & Request Vehicle",
                        icon: "paperplane.fill",
                        bgColor: Color(red: 0.90, green: 0.22, blue: 0.18),
                        isDisabled: !hasUploadedProofImages,
                        action: onSubmitVehicleChangeProof
                    )
                } else {
                    ActionButton(
                        label: "Next",
                        icon: "arrow.right",
                        bgColor: .appOrange,
                        action: onNext
                    )
                }

            case .signature:
                VStack(spacing: 10) {
                    ActionButton(
                        label: "Complete Inspection",
                        icon: "checkmark.seal.fill",
                        bgColor: Color(red: 0.20, green: 0.65, blue: 0.32),
                        isDisabled: !hasSigned,
                        action: onComplete
                    )

                    if isPostTrip {
                        SecondaryActionButton(
                            label: "Create Maintenance Request",
                            icon: "wrench.and.screwdriver.fill",
                            color: .appOrange,
                            action: onCreateMaintenanceRequest
                        )
                    }
                }
            }
        }
    }
}

struct ActionButton: View {
    let label: String
    let icon: String
    let bgColor: Color
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                Capsule()
                    .fill(isDisabled ? bgColor.opacity(0.4) : bgColor)
            )
            .shadow(
                color: isDisabled ? Color.clear : bgColor.opacity(0.3),
                radius: 12, x: 0, y: 6
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .scaleEffect(isDisabled ? 0.98 : 1.0)
        .animation(.spring(response: 0.3), value: isDisabled)
    }
}

struct SecondaryActionButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                Capsule()
                    .fill(color.opacity(0.10))
            )
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.35), lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct MaintenanceRequestModal: View {
    @Binding var text: String
    @Binding var proofImageAttached: Bool
    let onCancel: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.appOrange.opacity(0.18))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.appOrange)
                        )
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Maintenance Request")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Add notes for required maintenance")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }

                TextEditor(text: $text)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .frame(height: 110)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(red: 0.16, green: 0.16, blue: 0.17))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    proofImageAttached.toggle()
                }) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 44, height: 44)

                            Image(systemName: proofImageAttached ? "photo.fill" : "camera.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(proofImageAttached ? .green : .appOrange)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upload Proof Image")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                            Text(proofImageAttached ? "1 image attached" : "Tap to attach")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Image(systemName: proofImageAttached ? "checkmark.circle.fill" : "plus.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(proofImageAttached ? .green : .appOrange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(red: 0.16, green: 0.16, blue: 0.17))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(red: 0.17, green: 0.17, blue: 0.18))
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onSubmit) {
                        Text("Send")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.appOrange)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.11))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 96)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Inspection Complete Overlay
struct InspectionCompleteOverlay: View {
    let onDismiss: () -> Void
    @State private var scale: CGFloat = 0.5
    @State private var contentOpacity: Double = 0
    @State private var confettiVisible: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Animated checkmark
                ZStack {
                    // Confetti rings
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(
                                Color(red: 0.20, green: 0.65, blue: 0.32).opacity(confettiVisible ? 0 : 0.3),
                                lineWidth: 2
                            )
                            .frame(width: 80 + CGFloat(i) * 30, height: 80 + CGFloat(i) * 30)
                            .scaleEffect(confettiVisible ? 1.5 : 0.8)
                            .animation(
                                .easeOut(duration: 1.0)
                                .delay(Double(i) * 0.15),
                                value: confettiVisible
                            )
                    }

                    Circle()
                        .fill(Color(red: 0.20, green: 0.65, blue: 0.32))
                        .frame(width: 80, height: 80)
                        .shadow(color: Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.4), radius: 20)

                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(contentOpacity)
                }

                VStack(spacing: 8) {
                    Text("Inspection Complete!")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)

                    Text("You're all set to start your trip")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                }
                .opacity(contentOpacity)

                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onDismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 60)
                        .padding(.vertical, 15)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.20, green: 0.65, blue: 0.32))
                        )
                }
                .opacity(contentOpacity)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.14), radius: 30)
            )
            .scaleEffect(scale)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                scale = 1.0
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
                contentOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation { confettiVisible = true }
            }
        }
    }
}

struct VehicleChangeRequestedOverlay: View {
    let onDismiss: () -> Void
    @State private var scale: CGFloat = 0.5
    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.appOrange)
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.appOrange.opacity(0.4), radius: 18)

                    Image(systemName: "bus.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(spacing: 8) {
                    Text("Vehicle Change Requested")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)

                    Text("Proof images sent. Waiting for a new vehicle to be assigned.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(contentOpacity)

                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onDismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 60)
                        .padding(.vertical, 15)
                        .background(
                            Capsule()
                                .fill(Color.appOrange)
                        )
                }
                .opacity(contentOpacity)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.1), radius: 30)
            )
            .scaleEffect(scale)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                scale = 1.0
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.25)) {
                contentOpacity = 1.0
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        PreTripInspectionView()
    }
}
