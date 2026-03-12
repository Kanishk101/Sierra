import SwiftUI
import PhotosUI


struct DriverProfilePage2View: View {
    @Bindable var viewModel: DriverProfileViewModel

    // Photo picker state
    @State private var activePickerTarget: ImageTarget?
    @State private var selectedPhotoItem: PhotosPickerItem?

    enum ImageTarget {
        case aadhaarFront, aadhaarBack, licenseFront, licenseBack
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 4) {
                        Text("Documentation")
                            .font(SierraFont.title3)
                            .foregroundStyle(SierraTheme.Colors.primaryText)
                        Text("Upload your identity documents")
                            .font(SierraFont.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    // Aadhaar Section
                    documentSection("Aadhaar Card", icon: "creditcard.fill") {
                        // Aadhaar number
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 10) {
                                Image(systemName: "number")
                                    .font(SierraFont.caption1)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)

                                TextField("XXXX XXXX XXXX", text: Binding(
                                    get: { viewModel.formattedAadhaar },
                                    set: { viewModel.setAadhaarNumber($0) }
                                ))
                                .textFieldStyle(.plain)
                                .font(.system(size: 16, design: .monospaced))
                                .foregroundStyle(SierraTheme.Colors.primaryText)
                                .keyboardType(.numberPad)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(viewModel.aadhaarError != nil ? .red.opacity(0.5) : .clear, lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)

                            if let error = viewModel.aadhaarError {
                                inlineError(error)
                            }
                        }

                        // Image uploads
                        HStack(spacing: 12) {
                            imageUploadCard(
                                label: "Front",
                                image: viewModel.aadhaarFrontImage,
                                target: .aadhaarFront
                            )
                            imageUploadCard(
                                label: "Back",
                                image: viewModel.aadhaarBackImage,
                                target: .aadhaarBack
                            )
                        }

                        if let error = viewModel.aadhaarImagesError {
                            inlineError(error)
                        }
                    }

                    // License Section
                    documentSection("Driving License", icon: "car.fill") {
                        // License number
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 10) {
                                Image(systemName: "number")
                                    .font(SierraFont.caption1)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)

                                TextField("License Number", text: $viewModel.licenseNumber)
                                    .textFieldStyle(.plain)
                                    .font(SierraFont.bodyText)
                                    .foregroundStyle(SierraTheme.Colors.primaryText)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.characters)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(viewModel.licenseNumberError != nil ? .red.opacity(0.5) : .clear, lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)

                            if let error = viewModel.licenseNumberError {
                                inlineError(error)
                            }
                        }

                        // Expiry date
                        HStack(spacing: 10) {
                            Image(systemName: "calendar.badge.clock")
                                .font(SierraFont.caption1)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text("Expiry Date")
                                .font(SierraFont.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            DatePicker("", selection: $viewModel.licenseExpiryDate, in: Date()..., displayedComponents: .date)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)

                        // Image uploads
                        HStack(spacing: 12) {
                            imageUploadCard(
                                label: "Front",
                                image: viewModel.licenseFrontImage,
                                target: .licenseFront
                            )
                            imageUploadCard(
                                label: "Back",
                                image: viewModel.licenseBackImage,
                                target: .licenseBack
                            )
                        }

                        if let error = viewModel.licenseImagesError {
                            inlineError(error)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .scrollDismissesKeyboard(.interactively)

            // Bottom buttons
            bottomButtons
        }
        .photosPicker(
            isPresented: Binding(
                get: { activePickerTarget != nil },
                set: { if !$0 { activePickerTarget = nil } }
            ),
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let item = newItem, let target = activePickerTarget else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        assignImage(uiImage, to: target)
                    }
                }
                selectedPhotoItem = nil
                activePickerTarget = nil
            }
        }
        .overlay {
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.page2ValidationAttempted)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
    }

    // ─────────────────────────────────
    // MARK: - Image Upload Card
    // ─────────────────────────────────

    private func imageUploadCard(label: String, image: UIImage?, target: ImageTarget) -> some View {
        Group {
            if let image {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button {
                        removeImage(target)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white, .red)
                            .shadow(radius: 4)
                    }
                    .offset(x: 6, y: -6)
                }
                .frame(maxWidth: .infinity)
            } else {
                Button { activePickerTarget = target } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(SierraTheme.Colors.ember)

                        Text(label)
                            .font(SierraFont.caption1)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .foregroundStyle(SierraTheme.Colors.ember.opacity(0.4))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // ─────────────────────────────────
    // MARK: - Bottom Buttons
    // ─────────────────────────────────

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.goBack()
            } label: {
                Text("Back")
                    .font(SierraFont.body(17, weight: .semibold))
                    .foregroundStyle(SierraTheme.Colors.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(SierraTheme.Colors.sierraBlue.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .frame(maxWidth: .infinity)

            Button {
                Task { await viewModel.submitProfile() }
            } label: {
                Text("Submit Application")
                    .font(SierraFont.body(17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(SierraTheme.Colors.ember, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(.white.shadow(.drop(color: .black.opacity(0.06), radius: 8, y: -4)))
    }

    // ─────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────

    private func documentSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.ember)
                Text(title)
                    .font(SierraFont.body(14, weight: .bold))
                    .foregroundStyle(SierraTheme.Colors.granite)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            VStack(spacing: 10) {
                content()
            }
        }
    }

    private func inlineError(_ text: String) -> some View {
        Text(text)
            .font(SierraFont.caption2)
            .foregroundStyle(.red.opacity(0.85))
            .padding(.leading, 4)
            .transition(.opacity)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(SierraTheme.Colors.ember)
                Text("Submitting profile…")
                    .font(SierraFont.caption1)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .transition(.opacity)
    }

    private func assignImage(_ image: UIImage, to target: ImageTarget) {
        switch target {
        case .aadhaarFront:  viewModel.aadhaarFrontImage = image
        case .aadhaarBack:   viewModel.aadhaarBackImage = image
        case .licenseFront:  viewModel.licenseFrontImage = image
        case .licenseBack:   viewModel.licenseBackImage = image
        }
    }

    private func removeImage(_ target: ImageTarget) {
        switch target {
        case .aadhaarFront:  viewModel.aadhaarFrontImage = nil
        case .aadhaarBack:   viewModel.aadhaarBackImage = nil
        case .licenseFront:  viewModel.licenseFrontImage = nil
        case .licenseBack:   viewModel.licenseBackImage = nil
        }
    }
}

#Preview {
    DriverProfilePage2View(viewModel: DriverProfileViewModel())
}
