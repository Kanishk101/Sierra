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
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 4) {
                        Text("Documentation")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Upload your identity documents")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    // Aadhaar Section
                    documentSection("Aadhaar Card", icon: "creditcard.fill") {
                        // Aadhaar number
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 10) {
                                Image(systemName: "number")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)

                                TextField("XXXX XXXX XXXX", text: Binding(
                                    get: { viewModel.formattedAadhaar },
                                    set: { viewModel.setAadhaarNumber($0) }
                                ))
                                .textFieldStyle(.plain)
                                .font(.system(size: 16, design: .monospaced))
                                .foregroundStyle(.primary)
                                .keyboardType(.numberPad)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                                pickerItem: $aadhaarFrontItem
                            ) { viewModel.aadhaarFrontImage = $0 }

                            imageUploadCard(
                                label: "Back",
                                image: viewModel.aadhaarBackImage,
                                pickerItem: $aadhaarBackItem
                            ) { viewModel.aadhaarBackImage = $0 }
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
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)

                                TextField("License Number", text: $viewModel.licenseNumber)
                                    .textFieldStyle(.plain)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.characters)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text("Expiry Date")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            DatePicker("", selection: $viewModel.licenseExpiryDate, in: Date()..., displayedComponents: .date)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)

                        // Image uploads
                        HStack(spacing: 12) {
                            imageUploadCard(
                                label: "Front",
                                image: viewModel.licenseFrontImage,
                                pickerItem: $licenseFrontItem
                            ) { viewModel.licenseFrontImage = $0 }

                            imageUploadCard(
                                label: "Back",
                                image: viewModel.licenseBackImage,
                                pickerItem: $licenseBackItem
                            ) { viewModel.licenseBackImage = $0 }
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
        .overlay {
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.page2ValidationAttempted)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
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
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button {
                        onImageSelected(nil)
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
                PhotosPicker(selection: pickerItem, matching: .images) {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.orange)

                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .foregroundStyle(Color.orange.opacity(0.4))
                    )
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
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.goBack()
            } label: {
                Text("Back")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .frame(maxWidth: .infinity)

            Button {
                Task { await viewModel.submitProfile() }
            } label: {
                Text("Submit Application")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(Color(.systemBackground).shadow(.drop(color: .black.opacity(0.06), radius: 8, y: -4)))
    }

    // MARK: - Helpers

    private func documentSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
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
            .font(.caption2)
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
                    .tint(.orange)
                Text("Submitting profile\u{2026}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .transition(.opacity)
    }

}

#Preview {
    DriverProfilePage2View(viewModel: DriverProfileViewModel())
}
