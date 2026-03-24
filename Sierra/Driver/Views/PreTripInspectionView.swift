import SwiftUI
import PhotosUI
import UIKit
import PencilKit

/// Multi-step pre-trip / post-trip inspection form.
/// Step 1: Checklist  — every item must be explicitly set (Pass / Warn / Fail).
/// Step 2: Photos     — failed items require at least one photo.
/// Step 3: Summary    — review and submit.
@MainActor
struct PreTripInspectionView: View {

    let tripId: UUID
    let vehicleId: UUID
    let driverId: UUID
    let inspectionType: InspectionType
    var onComplete: () -> Void

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PreTripInspectionViewModel

    init(
        tripId: UUID,
        vehicleId: UUID,
        driverId: UUID,
        inspectionType: InspectionType = .preTripInspection,
        onComplete: @escaping () -> Void
    ) {
        self.tripId         = tripId
        self.vehicleId      = vehicleId
        self.driverId       = driverId
        self.inspectionType = inspectionType
        self.onComplete     = onComplete
        _viewModel = State(initialValue: PreTripInspectionViewModel(
            tripId: tripId,
            vehicleId: vehicleId,
            driverId: driverId,
            inspectionType: inspectionType
        ))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ZStack {
            Color.appSurface.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom nav bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: viewModel.currentStep == 1 ? "xmark" : "chevron.left")
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
                    Color.clear.frame(width: 38, height: 38)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Step progress bar
                stepIndicator
                    .padding(.horizontal, 40)
                    .padding(.bottom, 16)

                switch viewModel.currentStep {
                case 1:  checklistStep
                case 2:  mediaStep
                case 3:  signatureStep
                default: EmptyView()
                }
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: Binding(
            get: { viewModel.showOdometerCamera },
            set: { viewModel.showOdometerCamera = $0 }
        )) {
            OdometerCameraSheet { image in
                Task { @MainActor in
                    await viewModel.handleOCRImage(image)
                }
            }
        }
        .alert("Submission Error", isPresented: .init(
            get: { viewModel.submitError != nil },
            set: { if !$0 { viewModel.submitError = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(viewModel.submitError ?? "")
        }
        .onChange(of: viewModel.didSubmitSuccessfully) { _, success in
            if success { onComplete() }
        }
    }

    private var inspectionTitle: String {
        inspectionType == .preTripInspection ? "Pre-Trip Inspection" : "Post-Trip Inspection"
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(1...3, id: \.self) { step in
                ZStack {
                    Circle()
                        .fill(step <= viewModel.currentStep ? Color.appOrange : Color.appDivider)
                        .frame(width: 16, height: 16)
                    if step < viewModel.currentStep {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.white)
                    }
                }
                .scaleEffect(step == viewModel.currentStep ? 1.15 : 1.0)
                .animation(.spring(response: 0.35), value: viewModel.currentStep)

                if step < 3 {
                    Rectangle()
                        .fill(step < viewModel.currentStep ? Color.appOrange : Color.appDivider)
                        .frame(height: 3)
                        .animation(.easeInOut(duration: 0.4), value: viewModel.currentStep)
                }
            }
        }
    }

    // MARK: - Step 1: Checklist (Bug 6 redesign)
    // Odometer capture removed from this page — it now lives as a photo in Step 2.
    // Next button label adapts: all green = "All Clear → Next", has issues = "Log Issues → Next".

    private var checklistStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach($viewModel.checkItems) { $item in
                        checkItemRow(item: $item)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
            }

            Divider()

            // Validation counter — shown while there are unchecked items
            if viewModel.uncheckedCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text("Warning: \(viewModel.uncheckedCount) item(s) not yet checked")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
            }

            // Phase 11: Fuel level integration note
            if viewModel.fuelLevelNeedsAttention {
                HStack(spacing: 6) {
                    Text("⛽")
                        .font(.caption)
                    Text("Fuel level issue noted. Please log fuel after inspection.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.06))
            }

            // Bug 6: Adaptive Next button — label changes based on issue state
            let hasIssues = !viewModel.failedItems.isEmpty || !viewModel.warningItems.isEmpty
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { viewModel.currentStep = 2 }
            } label: {
                HStack(spacing: 8) {
                    Text(hasIssues ? "Log Issues → Next" : "All Clear → Next")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    Capsule()
                        .fill(hasIssues ? Color.appOrange : Color(red: 0.20, green: 0.65, blue: 0.32))
                )
                .shadow(
                    color: (hasIssues ? Color.appOrange : Color(red: 0.20, green: 0.65, blue: 0.32)).opacity(0.3),
                    radius: 12, x: 0, y: 6
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private func checkItemRow(item: Binding<InspectionCheckItem>) -> some View {
        VStack(spacing: 0) {
            // Main toggle row
            HStack(spacing: 14) {
                Image(systemName: item.wrappedValue.category.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.appOrange)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.wrappedValue.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                    Text(item.wrappedValue.category.rawValue)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { item.wrappedValue.result == .passed || item.wrappedValue.result == .notChecked },
                    set: { newValue in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            item.wrappedValue.result = newValue ? .passed : .failed
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .green))
                .labelsHidden()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.appCardBg)

            // Expanded issue details (when failed or warning)
            if item.wrappedValue.result == .failed || item.wrappedValue.result == .passedWithWarnings {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Status")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)

                    HStack(spacing: 12) {
                        // Warn button
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                item.wrappedValue.result = .passedWithWarnings
                            }
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            Text("Warn")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(item.wrappedValue.result == .passedWithWarnings ? .white : .appOrange)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(item.wrappedValue.result == .passedWithWarnings ? Color.appOrange : Color.clear)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.appOrange, lineWidth: item.wrappedValue.result == .passedWithWarnings ? 0 : 2)
                                )
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(item.wrappedValue.result == .passedWithWarnings ? 1.03 : 1.0)

                        // Fail button
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                item.wrappedValue.result = .failed
                            }
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            Text("Fail")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(item.wrappedValue.result == .failed ? .white : Color(red: 0.90, green: 0.22, blue: 0.18))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(item.wrappedValue.result == .failed ? Color(red: 0.90, green: 0.22, blue: 0.18) : Color.clear)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color(red: 0.90, green: 0.22, blue: 0.18), lineWidth: item.wrappedValue.result == .failed ? 0 : 2)
                                )
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(item.wrappedValue.result == .failed ? 1.03 : 1.0)
                    }

                    Text("Issue Details")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)

                    TextEditor(text: item.notes)
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
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
    }

    // MARK: - Step 2: Media Captures (Bug 6 redesign)

    @State private var fuelPhoto: UIImage?
    @State private var odometerPhoto: UIImage?
    @State private var showFuelCamera = false
    @State private var showOdometerCam = false

    private var mediaStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Header ──────────────────────────────────────────────
                    VStack(spacing: 6) {
                        Image(systemName: "camera.badge.ellipsis")
                            .font(.system(size: 36))
                            .foregroundStyle(SierraTheme.Colors.ember.opacity(0.7))
                        Text("Document Vehicle State")
                            .font(.headline)
                        Text("Capture fuel gauge and odometer photos before departure.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    // ── Fuel Status photo ────────────────────────────────────
                    photoCaptureRow(
                        title: "Fuel Status",
                        subtitle: "Photograph the fuel gauge",
                        icon: "fuelpump.fill",
                        accent: SierraTheme.Colors.warning,
                        capturedImage: fuelPhoto,
                        onTap: { showFuelCamera = true }
                    )

                    // ── Odometer photo ───────────────────────────────────────
                    photoCaptureRow(
                        title: "Odometer Reading",
                        subtitle: "Photograph the odometer display",
                        icon: "speedometer",
                        accent: SierraTheme.Colors.ember,
                        capturedImage: odometerPhoto,
                        onTap: { showOdometerCam = true }
                    )

                    // ── Failed items still need per-item photos ──────────────
                    if !viewModel.itemsNeedingPhotos.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Issue Documentation", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(SierraTheme.Colors.danger)
                            ForEach(viewModel.itemsNeedingPhotos) { item in
                                itemPhotoRow(item: item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .sheet(isPresented: $showFuelCamera) {
                OdometerCameraSheet { img in
                    fuelPhoto = img
                    if let data = img.jpegData(compressionQuality: 0.8) {
                        viewModel.generalPhotoData.append(data)
                    }
                }
            }
            .sheet(isPresented: $showOdometerCam) {
                OdometerCameraSheet { img in
                    odometerPhoto = img
                    Task { @MainActor in await viewModel.handleOCRImage(img) }
                    if let data = img.jpegData(compressionQuality: 0.8) {
                        viewModel.generalPhotoData.append(data)
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { viewModel.currentStep = 1 }
                } label: {
                    Text("Back")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Capsule().fill(Color.appSurface))
                        .overlay(Capsule().stroke(Color.appDivider, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { viewModel.currentStep = 3 }
                } label: {
                    HStack(spacing: 8) {
                        Text("Next")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Capsule().fill(Color.appOrange))
                    .shadow(color: Color.appOrange.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
    }

    /// Reusable camera capture row for Step 2.
    private func photoCaptureRow(
        title: String,
        subtitle: String,
        icon: String,
        accent: Color,
        capturedImage: UIImage?,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.12))
                        .frame(width: 48, height: 48)
                    if let img = capturedImage {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(accent)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                    Text(capturedImage == nil ? subtitle : "✓ Photo captured — tap to retake")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(capturedImage == nil ? .appTextSecondary : Color(red: 0.20, green: 0.65, blue: 0.32))
                }

                Spacer()

                Image(systemName: capturedImage == nil ? "camera.fill" : "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(capturedImage == nil ? accent : Color(red: 0.20, green: 0.65, blue: 0.32))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(capturedImage == nil ? accent.opacity(0.06) : Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(capturedImage == nil ? accent.opacity(0.2) : Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }



    /// A single row showing one check item with its own photo picker.
    /// Red = failed (REQUIRED), orange = warning (RECOMMENDED).
    @ViewBuilder
    private func itemPhotoRow(item: InspectionCheckItem) -> some View {
        let isFailed         = item.result == .failed
        let accent: Color    = isFailed ? SierraTheme.Colors.danger : SierraTheme.Colors.warning
        let badge            = isFailed ? "Required" : "Recommended"
        let dataCount        = viewModel.itemPhotoData[item.id]?.count ?? 0
        let hasPhoto         = dataCount > 0

        VStack(alignment: .leading, spacing: 10) {
            // ── Item header ─────────────────────────────────────────
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isFailed ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(accent)
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                    if !item.notes.isEmpty {
                        Text(item.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(badge)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.12),
                                in: Capsule())
            }

            // ── Photo picker for this item ──────────────────────────
            PhotosPicker(
                selection: Binding(
                    get: { viewModel.itemPhotoSelections[item.id] ?? [] },
                    set: { newVal in
                        viewModel.itemPhotoSelections[item.id] = newVal
                        Task { @MainActor in
                            await viewModel.loadPhotosForItem(item.id, selections: newVal)
                        }
                    }
                ),
                maxSelectionCount: 4,
                matching: .images
            ) {
                HStack(spacing: 8) {
                    if hasPhoto {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(SierraTheme.Colors.alpineMint)
                        Text("\(dataCount) photo(s) added")
                            .foregroundStyle(SierraTheme.Colors.alpineMint)
                    } else {
                        Image(systemName: "camera.fill")
                            .foregroundStyle(accent)
                        Text(isFailed ? "Add photo (required)" : "Add photo (optional)")
                            .foregroundStyle(accent)
                    }
                }
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            (hasPhoto ? SierraTheme.Colors.alpineMint : accent).opacity(0.5),
                            lineWidth: 1.3
                        )
                )
            }
        }
        .padding(14)
        .background(
            accent.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(accent.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Step 3: Signature (Bug 6 redesign)
    // PencilKit signature canvas + submit.

    @State private var canvasView = PKCanvasView()
    @State private var signatureIsEmpty = true

    private var signatureStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Summary header ──────────────────────────────────────
                    resultBanner.padding(.horizontal, 16)

                    if !viewModel.failedItems.isEmpty {
                        issuesList("Failed Items", items: viewModel.failedItems, color: SierraTheme.Colors.danger)
                            .padding(.horizontal, 16)
                    }
                    if !viewModel.warningItems.isEmpty {
                        issuesList("Warnings", items: viewModel.warningItems, color: SierraTheme.Colors.warning)
                            .padding(.horizontal, 16)
                    }

                    // ── Signature canvas ──────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "signature")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.appOrange)
                            Text("Driver Signature")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.appTextPrimary)
                            Spacer()
                            if !signatureIsEmpty {
                                Button("Clear") {
                                    canvasView.drawing = PKDrawing()
                                    signatureIsEmpty = true
                                    viewModel.signatureImage = nil
                                }
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.appOrange)
                            }
                        }

                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white)
                                .frame(height: 160)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appDivider, lineWidth: 1.5))

                            if signatureIsEmpty {
                                Text("Sign here with your finger")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.appTextSecondary.opacity(0.5))
                            }

                            SignatureCanvasView(canvasView: $canvasView) {
                                let image = canvasView.drawing.image(from: canvasView.bounds, scale: 3.0)  // 3x Retina
                                viewModel.signatureImage = image
                                signatureIsEmpty = canvasView.drawing.strokes.isEmpty
                            }
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Text("I certify that this vehicle has been inspected and is roadworthy.")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.appTextSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.appCardBg))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appDivider.opacity(0.5), lineWidth: 1))
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)
            }

            if viewModel.isSubmitting || viewModel.isUploadingPhotos {
                VStack(spacing: 8) {
                    ProgressView()
                    if !viewModel.uploadProgress.isEmpty {
                        Text(viewModel.uploadProgress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }

            HStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { viewModel.currentStep = 2 }
                } label: {
                    Text("Back")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Capsule().fill(Color.appSurface))
                        .overlay(Capsule().stroke(Color.appDivider, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    Task { await viewModel.submitInspection(store: store) }
                } label: {
                    HStack(spacing: 8) {
                        Text("Complete Inspection")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        Capsule()
                            .fill((viewModel.isSubmitting || !viewModel.canSubmit)
                                ? Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.4)
                                : Color(red: 0.20, green: 0.65, blue: 0.32))
                    )
                    .shadow(
                        color: (viewModel.isSubmitting || !viewModel.canSubmit)
                            ? Color.clear
                            : Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.3),
                        radius: 12, x: 0, y: 6
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSubmitting || !viewModel.canSubmit)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Subviews

    private var resultBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: resultIcon)
                .font(.title2)
                .foregroundStyle(resultColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Overall Result")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.overallResult.rawValue)
                    .font(.headline)
                    .foregroundStyle(resultColor)
            }
            Spacer()
        }
        .padding(14)
        .background(
            resultColor.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private func issuesList(
        _ title: String,
        items: [InspectionCheckItem],
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            ForEach(items) { item in
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(color)
                    VStack(alignment: .leading) {
                        Text(item.name).font(.caption.weight(.medium))
                        if !item.notes.isEmpty {
                            Text(item.notes)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(
            color.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 10)
        )
    }

    private var resultIcon: String {
        switch viewModel.overallResult {
        case .passed:             return "checkmark.seal.fill"
        case .passedWithWarnings: return "exclamationmark.triangle.fill"
        case .failed:             return "xmark.seal.fill"
        case .notChecked:         return "questionmark.circle"
        }
    }

    private var resultColor: Color {
        switch viewModel.overallResult {
        case .passed:             return SierraTheme.Colors.alpineMint
        case .passedWithWarnings: return SierraTheme.Colors.warning
        case .failed:             return SierraTheme.Colors.danger
        case .notChecked:         return .gray
        }
    }
    // MARK: - Odometer Capture Card

    @ViewBuilder
    private var odometerCaptureCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Odometer Reading", systemImage: "speedometer")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            // State-driven display
            switch viewModel.odometerOCRState {
            case .idle:
                // Show camera scan button
                Button {
                    viewModel.showOdometerCamera = true
                    viewModel.odometerOCRState = .scanning
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scan Odometer")
                                .font(.subheadline.weight(.semibold))
                            Text("Point camera at odometer display")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(SierraTheme.Colors.ember.opacity(0.3), lineWidth: 1.2)
                    )
                }
                .buttonStyle(.plain)

                // OR separator
                HStack(spacing: 10) {
                    VStack { Divider() }
                    Text("OR")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    VStack { Divider() }
                }
                .padding(.vertical, 2)

                manualEntryField

            case .scanning:
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("Running OCR…").font(.caption).foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 12))

            case .result(let reading):
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("OCR detected: \(reading) km")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Button("Retry") {
                            viewModel.odometerOCRState = .idle
                            viewModel.odometerText = ""
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.07),
                                in: RoundedRectangle(cornerRadius: 12))

                    // OR separator
                    HStack(spacing: 10) {
                        VStack { Divider() }
                        Text("OR")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                        VStack { Divider() }
                    }
                    .padding(.vertical, 2)

                    manualEntryField
                }

            case .failed:
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("OCR couldn't read odometer — enter manually")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Retry") {
                            viewModel.showOdometerCamera = true
                            viewModel.odometerOCRState = .scanning
                        }
                        .font(.caption)
                        .foregroundStyle(SierraTheme.Colors.ember)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.07),
                                in: RoundedRectangle(cornerRadius: 10))
                    manualEntryField
                }

            case .confirmed:
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("\(viewModel.odometerText) km confirmed")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Button("Edit") { viewModel.odometerOCRState = .failed }
                        .font(.caption).foregroundStyle(.orange)
                }
                .padding(12)
                .background(Color.green.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var manualEntryField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Manual entry").font(.caption2).foregroundStyle(.tertiary)
            HStack(spacing: 8) {
                TextField("e.g. 45230", text: Binding(
                    get: { viewModel.odometerText },
                    set: { viewModel.odometerText = $0 }
                ))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                Text("km").font(.caption).foregroundStyle(.secondary)
                if viewModel.odometerReading != nil {
                    Button {
                        viewModel.odometerOCRState = .confirmed
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title3)
                    }
                }
            }
        }
    }
}

// MARK: - SignatureCanvasView (PencilKit wrapper for Step 3)

struct SignatureCanvasView: UIViewRepresentable {

    @Binding var canvasView: PKCanvasView
    var onChanged: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChanged: onChanged) }

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 2)
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = context.coordinator
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let onChanged: () -> Void
        init(onChanged: @escaping () -> Void) { self.onChanged = onChanged }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) { onChanged() }
    }
}

// MARK: - OdometerCameraSheet
struct OdometerCameraSheet: UIViewControllerRepresentable {

    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: OdometerCameraSheet
        init(parent: OdometerCameraSheet) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
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
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(
                                Color(red: 0.20, green: 0.65, blue: 0.32).opacity(confettiVisible ? 0 : 0.3),
                                lineWidth: 2
                            )
                            .frame(width: 80 + CGFloat(i) * 30, height: 80 + CGFloat(i) * 30)
                            .scaleEffect(confettiVisible ? 1.5 : 0.8)
                            .animation(
                                .easeOut(duration: 1.0).delay(Double(i) * 0.15),
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
                        .background(Capsule().fill(Color(red: 0.20, green: 0.65, blue: 0.32)))
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
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { scale = 1.0 }
            withAnimation(.easeOut(duration: 0.3).delay(0.3)) { contentOpacity = 1.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation { confettiVisible = true }
            }
        }
    }
}

// MARK: - Vehicle Change Requested Overlay
struct InspectionVehicleChangeOverlay: View {
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
                        .background(Capsule().fill(Color.appOrange))
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
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { scale = 1.0 }
            withAnimation(.easeOut(duration: 0.3).delay(0.25)) { contentOpacity = 1.0 }
        }
    }
}

// MARK: - Maintenance Request Modal
struct InspectionMaintenanceModal: View {
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
        }
    }
}
