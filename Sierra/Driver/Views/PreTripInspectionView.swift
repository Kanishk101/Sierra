import SwiftUI
import PhotosUI

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
    @State private var photoItems: [PhotosPickerItem] = []

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
        VStack(spacing: 0) {
            stepIndicator
            Divider()

            switch viewModel.currentStep {
            case 1:  checklistStep
            case 2:  photoStep
            case 3:  summaryStep
            default: EmptyView()
            }
        }
        .navigationTitle(inspectionTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
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
                HStack(spacing: 6) {
                    Circle()
                        .fill(step <= viewModel.currentStep
                              ? SierraTheme.Colors.ember
                              : Color(.tertiaryLabel))
                        .frame(width: 24, height: 24)
                        .overlay {
                            if step < viewModel.currentStep {
                                Image(systemName: "checkmark")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                            } else {
                                Text("\(step)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(
                                        step == viewModel.currentStep ? .white : .secondary
                                    )
                            }
                        }
                    if step < 3 {
                        Rectangle()
                            .fill(step < viewModel.currentStep
                                  ? SierraTheme.Colors.ember
                                  : Color(.tertiaryLabel).opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    // MARK: - Step 1: Checklist

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
                    Text("\u26a0\ufe0f \(viewModel.uncheckedCount) item(s) not yet checked")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
            }

            Button {
                withAnimation { viewModel.currentStep = 2 }
            } label: {
                Text("Next: Photos")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        viewModel.canAdvanceToPhotos
                            ? SierraTheme.Colors.ember
                            : Color.gray,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            // Disabled until every item is explicitly set
            .disabled(!viewModel.canAdvanceToPhotos)
            .padding(16)
        }
    }

    private func checkItemRow(item: Binding<InspectionCheckItem>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.wrappedValue.name)
                        .font(.subheadline.weight(.medium))
                    Text(item.wrappedValue.category.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                // Segmented picker — does NOT show .notChecked as an option;
                // the driver must actively choose Pass, Warn, or Fail.
                Picker("", selection: item.result) {
                    Text("Pass").tag(InspectionResult.passed)
                    Text("Warn").tag(InspectionResult.passedWithWarnings)
                    Text("Fail").tag(InspectionResult.failed)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            if item.wrappedValue.result == .failed
                || item.wrappedValue.result == .passedWithWarnings {
                TextField("Notes (optional)", text: item.notes)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    // MARK: - Step 2: Photos

    private var photoStep: some View {
        let count       = photoItems.count
        let buttonTitle = count == 0 ? "Select Photos" : "\(count) photo(s) selected"

        return VStack(spacing: 16) {
            Spacer()

            // Required-photos banner — shown when there are failed items
            // and no photos have been added yet.
            if !viewModel.failedItemsMissingPhoto.isEmpty {
                let names = viewModel.failedItemsMissingPhoto
                    .map(\.name)
                    .joined(separator: ", ")
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(SierraTheme.Colors.danger)
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Photos required for failed items")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SierraTheme.Colors.danger)
                        Text(names)
                            .font(.caption)
                            .foregroundStyle(SierraTheme.Colors.danger.opacity(0.8))
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SierraTheme.Colors.danger.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 16)
            }

            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundStyle(SierraTheme.Colors.ember.opacity(0.6))

            Text("Add Inspection Photos")
                .font(.headline)

            Text("Upload up to 5 photos of the vehicle condition")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            PhotosPicker(
                selection: $photoItems,
                maxSelectionCount: 5,
                matching: .images
            ) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text(buttonTitle)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(SierraTheme.Colors.ember)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(SierraTheme.Colors.ember.opacity(0.5), lineWidth: 1.5)
                )
            }
            .onChange(of: photoItems) { _, newItems in
                viewModel.selectedPhotoItems = newItems
                Task { @MainActor in await viewModel.loadPhotos() }
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    withAnimation { viewModel.currentStep = 1 }
                } label: {
                    Text("Back")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                }

                let photoStepBlocked = !viewModel.failedItemsMissingPhoto.isEmpty

                Button {
                    withAnimation { viewModel.currentStep = 3 }
                } label: {
                    Text("Next: Summary")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            photoStepBlocked ? Color.gray : SierraTheme.Colors.ember,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                }
                // Disabled until failed items have at least one photo
                .disabled(photoStepBlocked)
            }
            .padding(16)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Step 3: Summary + Submit

    private var summaryStep: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(spacing: 16) {
                    resultBanner

                    if !viewModel.failedItems.isEmpty {
                        issuesList(
                            "Failed Items",
                            items: viewModel.failedItems,
                            color: SierraTheme.Colors.danger
                        )
                    }
                    if !viewModel.warningItems.isEmpty {
                        issuesList(
                            "Warnings",
                            items: viewModel.warningItems,
                            color: SierraTheme.Colors.warning
                        )
                    }

                    if !viewModel.photoData.isEmpty {
                        HStack {
                            Image(systemName: "photo.fill")
                                .foregroundStyle(.secondary)
                            Text("\(viewModel.photoData.count) photo(s) will be uploaded")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(12)
                        .background(
                            Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
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
                    withAnimation { viewModel.currentStep = 2 }
                } label: {
                    Text("Back")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                }

                Button {
                    Task { await viewModel.submitInspection(store: store) }
                } label: {
                    Text("Submit Inspection")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            (viewModel.isSubmitting || !viewModel.canSubmit)
                                ? Color.gray
                                : SierraTheme.Colors.ember,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                }
                .disabled(viewModel.isSubmitting || !viewModel.canSubmit)
            }
            .padding(16)
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
}
