import SwiftUI
import PhotosUI

struct DriverProfilePage2View: View {
    @Bindable var viewModel: DriverProfileViewModel

    // Per-target photo picker items
    @State private var aadhaarFrontItem: PhotosPickerItem?
    @State private var aadhaarBackItem: PhotosPickerItem?
    @State private var licenseFrontItem: PhotosPickerItem?
    @State private var licenseBackItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Documentation")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(SierraTheme.Colors.primaryText)
                        Text("Upload valid identification documents for verification")
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
                            errorMessage: viewModel.aadhaarError,
                            maxLength: 14, // 12 digits + 2 spaces
                            filterDigitsOnly: false // Formatting happens in VM
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

                    // License Section
                    documentSection("Driving License", icon: "car.fill") {
                        SierraTextField(
                            label: "License Number",
                            placeholder: "Enter license number",
                            text: $viewModel.licenseNumber,
                            style: .native,
                            leadingIcon: "number",
                            errorMessage: viewModel.licenseNumberError,
                            maxLength: 20
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
                                
                                DatePicker("", selection: $viewModel.licenseExpiryDate, in: Date()..., displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(SierraTheme.Colors.ember)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 54)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                            .sierraShadow(SierraTheme.Shadow.card)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("License Expiry Date")

                        // Image uploads
                        VStack(alignment: .leading, spacing: 12) {
                            Text("LICENSE PHOTOS")
                                .font(SierraFont.caption2.weight(.bold))
                                .foregroundStyle(SierraTheme.Colors.secondaryText)
                                .tracking(0.5)

                            HStack(spacing: 16) {
                                imageUploadCard(
                                    label: "Front Side",
                                    image: viewModel.licenseFrontImage,
                                    pickerItem: $licenseFrontItem
                                ) { viewModel.licenseFrontImage = $0 }

                                imageUploadCard(
                                    label: "Back Side",
                                    image: viewModel.licenseBackImage,
                                    pickerItem: $licenseBackItem
                                ) { viewModel.licenseBackImage = $0 }
                            }
                        }

                        if let error = viewModel.licenseImagesError {
                            inlineError(error)
                        }
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
                        .frame(height: 110)
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
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(SierraTheme.Colors.ember.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: "camera.fill")
                                .font(SierraFont.scaled(18))
                                .foregroundStyle(SierraTheme.Colors.ember)
                        }

                        Text(label)
                            .font(SierraFont.caption2.weight(.semibold))
                            .foregroundStyle(SierraTheme.Colors.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
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
    
    // Helper to get width for button sizing
    private var geoWidth: CGFloat {
        375.0 // fallback width
    }

    // MARK: - Helpers

    private func documentSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(SierraTheme.Colors.ember.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(SierraFont.scaled(14))
                        .foregroundStyle(SierraTheme.Colors.ember)
                }
                
                Text(title)
                    .font(SierraFont.body(16, weight: .bold))
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

#Preview {
    DriverProfilePage2View(viewModel: DriverProfileViewModel())
}
