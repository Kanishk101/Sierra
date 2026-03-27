import SwiftUI
import PhotosUI

struct MaintenanceProfilePage2View: View {
    @Bindable var viewModel: MaintenanceProfileViewModel

    // Per-target photo picker items
    @State private var aadhaarFrontItem: PhotosPickerItem?
    @State private var aadhaarBackItem: PhotosPickerItem?
    @State private var certificateItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Professional Documents")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(SierraTheme.Colors.primaryText)
                        Text("Upload your identity & professional credentials")
                            .font(SierraFont.caption1)
                            .foregroundStyle(SierraTheme.Colors.secondaryText)
                    }
                    .padding(.top, 16)

                    // Aadhaar Section
                    documentSection("Aadhaar Card", icon: "creditcard.fill") {
                        SierraTextField(
                            label: "Aadhaar Number",
                            placeholder: "XXXX XXXX XXXX",
                            text: Binding(
                                get: { viewModel.formattedAadhaar },
                                set: { viewModel.setAadhaarNumber($0) }
                            ),
                            style: .native,
                            keyboardType: .numberPad,
                            leadingIcon: "number",
                            errorMessage: viewModel.aadhaarError,
                            maxLength: 14 // 12 digits + 2 spaces
                        )
                        .font(SierraFont.scaled(16, design: .monospaced))

                        // Image uploads
                        VStack(alignment: .leading, spacing: 12) {
                            Text("FRONT & BACK PHOTOS")
                                .font(SierraFont.caption2.weight(.bold))
                                .foregroundStyle(SierraTheme.Colors.secondaryText)
                                .tracking(0.5)

                            HStack(spacing: 16) {
                                imageUploadCard(
                                    label: "Front Side",
                                    image: viewModel.aadhaarFrontImage,
                                    pickerItem: $aadhaarFrontItem
                                ) { viewModel.aadhaarFrontImage = $0 }

                                imageUploadCard(
                                    label: "Back Side",
                                    image: viewModel.aadhaarBackImage,
                                    pickerItem: $aadhaarBackItem
                                ) { viewModel.aadhaarBackImage = $0 }
                            }
                        }

                        if let error = viewModel.aadhaarImagesError {
                            inlineError(error)
                        }
                    }

                    // Technical Certification Section
                    documentSection("Technical Certification", icon: "wrench.and.screwdriver.fill") {
                        // Certification type picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CERTIFICATION TYPE")
                                .font(SierraFont.caption2.weight(.bold))
                                .foregroundStyle(SierraTheme.Colors.secondaryText)
                                .tracking(0.5)

                            HStack(spacing: 12) {
                                Image(systemName: "doc.text.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(SierraTheme.Colors.secondaryText)
                                    .frame(width: 24)
                                
                                Text("Select Type")
                                    .font(SierraFont.body(16))
                                    .foregroundStyle(SierraTheme.Colors.primaryText)
                                
                                Spacer()
                                
                                Picker("", selection: $viewModel.certificationType) {
                                    ForEach(CertificationType.allCases, id: \.self) {
                                        Text($0.rawValue).tag($0)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(SierraTheme.Colors.ember)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 54)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                            .sierraShadow(SierraTheme.Shadow.card)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Certification Type")

                        SierraTextField(
                            label: "Certification Number",
                            placeholder: "Enter cert number",
                            text: $viewModel.certificationNumber,
                            style: .native,
                            leadingIcon: "number",
                            errorMessage: viewModel.certNumberError,
                            maxLength: 30
                        )

                        SierraTextField(
                            label: "Issuing Authority",
                            placeholder: "Company or Body",
                            text: $viewModel.issuingAuthority,
                            style: .native,
                            leadingIcon: "building.columns.fill",
                            errorMessage: viewModel.authorityError,
                            maxLength: 100
                        )

                        // Expiry date
                        VStack(alignment: .leading, spacing: 10) {
                            Text("EXPIRY DATE")
                                .font(SierraFont.caption2.weight(.bold))
                                .foregroundStyle(SierraTheme.Colors.secondaryText)
                                .tracking(0.5)

                            HStack(spacing: 12) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.subheadline)
                                    .foregroundStyle(SierraTheme.Colors.secondaryText)
                                    .frame(width: 24)
                                
                                Text("Select Expiry")
                                    .font(SierraFont.body(16))
                                    .foregroundStyle(SierraTheme.Colors.primaryText)
                                
                                Spacer()
                                
                                DatePicker("", selection: $viewModel.certExpiryDate, in: Date()..., displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(SierraTheme.Colors.ember)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 54)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                            .sierraShadow(SierraTheme.Shadow.card)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Certification Expiry Date")

                        // Certificate image
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CERTIFICATE PHOTO")
                                .font(SierraFont.caption2.weight(.bold))
                                .foregroundStyle(SierraTheme.Colors.secondaryText)
                                .tracking(0.5)

                            imageUploadCard(
                                label: "Upload Certificate",
                                image: viewModel.certificateImage,
                                pickerItem: $certificateItem
                            ) { viewModel.certificateImage = $0 }
                        }

                        if let error = viewModel.certImageError {
                            inlineError(error)
                        }
                    }

                    // Work Experience Section
                    documentSection("Work Experience", icon: "briefcase.fill") {
                        // Years of experience
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(SierraTheme.Colors.secondaryText)
                                    .frame(width: 24)
                                
                                Text("Years of Experience")
                                    .font(SierraFont.body(16))
                                    .foregroundStyle(SierraTheme.Colors.primaryText)
                                
                                Spacer()
                                
                                Stepper("\(viewModel.yearsOfExperience) yrs", value: $viewModel.yearsOfExperience, in: 0...40)
                                    .font(SierraFont.body(16, weight: .semibold))
                                    .foregroundStyle(SierraTheme.Colors.ember)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 54)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                            .sierraShadow(SierraTheme.Shadow.card)
                        }

                        // Specialization chips
                        VStack(alignment: .leading, spacing: 16) {
                            Text("SPECIALIZATIONS")
                                .font(SierraFont.caption2.weight(.bold))
                                .foregroundStyle(SierraTheme.Colors.secondaryText)
                                .tracking(0.5)

                            FlowLayout(spacing: 10) {
                                ForEach(Specialization.allCases) { spec in
                                    chipButton(spec)
                                }
                            }
                        }
                        .padding(20)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                        .sierraShadow(SierraTheme.Shadow.card)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 140)
            }
            .scrollDismissesKeyboard(.interactively)

            // Bottom buttons
            bottomButtons
        }
        .overlay {
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: viewModel.page2ValidationAttempted)
    }

    // MARK: - Chip Button

    private func chipButton(_ spec: Specialization) -> some View {
        let isSelected = viewModel.selectedSpecializations.contains(spec)
        return Button {
            withAnimation(.spring(duration: 0.3, bounce: 0.3)) {
                viewModel.toggleSpecialization(spec)
            }
        } label: {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(SierraFont.scaled(10, weight: .bold))
                }
                Text(spec.rawValue)
                    .font(SierraFont.caption1.weight(isSelected ? .bold : .medium))
            }
            .foregroundStyle(isSelected ? .white : SierraTheme.Colors.secondaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isSelected ? SierraTheme.Colors.ember : Color.clear,
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? SierraTheme.Colors.ember : SierraTheme.Colors.cloud, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Image Upload Card

    private func imageUploadCard(
        label: String,
        image: UIImage?,
        pickerItem: Binding<PhotosPickerItem?>,
        onImageSelected: @escaping (UIImage?) -> Void
    ) -> some View {
        Group {
            if let image {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                                .strokeBorder(SierraTheme.Colors.cloud.opacity(0.3), lineWidth: 1)
                        )

                    Button {
                        onImageSelected(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(SierraFont.scaled(24))
                            .foregroundStyle(.white, SierraTheme.Colors.danger)
                            .shadow(radius: 4)
                    }
                    .offset(x: 8, y: -8)
                }
            } else {
                PhotosPicker(selection: pickerItem, matching: .images) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(SierraTheme.Colors.ember.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: "camera.fill")
                                .font(SierraFont.scaled(20))
                                .foregroundStyle(SierraTheme.Colors.ember)
                        }

                        Text(label)
                            .font(SierraFont.caption1.weight(.semibold))
                            .foregroundStyle(SierraTheme.Colors.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .foregroundStyle(SierraTheme.Colors.ember.opacity(0.3))
                    )
                    .background(SierraTheme.Colors.ember.opacity(0.02), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                }
                .buttonStyle(.plain)
                .onChange(of: pickerItem.wrappedValue) { _, newItem in
                    guard let item = newItem else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            await MainActor.run {
                                onImageSelected(uiImage)
                            }
                        }
                        await MainActor.run {
                            pickerItem.wrappedValue = nil
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) document photo")
        .accessibilityHint(image == nil ? "Tap to select an image" : "Tap the remove button to clear")
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        VStack(spacing: 0) {
            Divider().background(SierraTheme.Colors.cloud.opacity(0.5))
            
            HStack(spacing: 16) {
                SierraButton.secondary("Back") {
                    viewModel.goBack()
                }
                .frame(maxWidth: geoWidth * 0.35)

                SierraButton.primary("Submit Application") {
                    Task { await viewModel.submitProfile() }
                }
            }
            .padding(24)
            .background(SierraTheme.Colors.appBackground)
        }
    }
    
    private var geoWidth: CGFloat {
        // Use a generic width since we are in a ScrollView and want it to be responsive
        // or we could use GeometryReader, but for a simple fix:
        375.0 // fallback width
    }

    // MARK: - Helpers

    private func documentSection(_ title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(SierraTheme.Colors.ember.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(SierraFont.scaled(15))
                        .foregroundStyle(SierraTheme.Colors.ember)
                }
                
                Text(title)
                    .font(SierraFont.body(17, weight: .bold))
                    .foregroundStyle(SierraTheme.Colors.primaryText)
            }

            VStack(spacing: 24) {
                content()
            }
        }
        .padding(.vertical, 8)
    }

    private func inlineError(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption2)
            Text(text)
                .font(SierraFont.caption2)
        }
        .foregroundStyle(SierraTheme.Colors.danger)
        .padding(.leading, 4)
        .transition(.opacity)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(SierraTheme.Colors.ember)
                Text("Submitting profile\u{2026}")
                    .font(SierraFont.body(16, weight: .medium))
                    .foregroundStyle(SierraTheme.Colors.primaryText)
            }
            .padding(40)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        }
        .transition(.opacity)
    }
}

// MARK: - Flow Layout (for multi-select chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

#Preview {
    MaintenanceProfilePage2View(viewModel: MaintenanceProfileViewModel())
}
