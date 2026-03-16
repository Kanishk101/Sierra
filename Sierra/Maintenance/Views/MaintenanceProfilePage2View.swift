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
                VStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("Professional Documents")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Upload your identity & professional credentials")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    // Aadhaar Section
                    docSection("Aadhaar Card", icon: "creditcard.fill") {
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

                        HStack(spacing: 12) {
                            imageUploadCard(label: "Front", image: viewModel.aadhaarFrontImage, pickerItem: $aadhaarFrontItem) { viewModel.aadhaarFrontImage = $0 }
                            imageUploadCard(label: "Back", image: viewModel.aadhaarBackImage, pickerItem: $aadhaarBackItem) { viewModel.aadhaarBackImage = $0 }
                        }

                        if let error = viewModel.aadhaarImagesError {
                            inlineError(error)
                        }
                    }

                    // Technical Certification Section
                    docSection("Technical Certification", icon: "wrench.and.screwdriver.fill") {
                        // Certification type picker
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text("Type")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("", selection: $viewModel.certificationType) {
                                ForEach(CertificationType.allCases, id: \.self) {
                                    Text($0.rawValue).tag($0)
                                }
                            }
                            .tint(.primary)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)

                        // Certification number
                        validatedField(icon: "number", placeholder: "Certification Number", text: $viewModel.certificationNumber, error: viewModel.certNumberError)

                        // Issuing authority
                        validatedField(icon: "building.columns.fill", placeholder: "Issuing Authority", text: $viewModel.issuingAuthority, error: viewModel.authorityError, autocap: .words)

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
                            DatePicker("", selection: $viewModel.certExpiryDate, in: Date()..., displayedComponents: .date)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)

                        // Certificate image
                        imageUploadCard(label: "Certificate", image: viewModel.certificateImage, pickerItem: $certificateItem) { viewModel.certificateImage = $0 }

                        if let error = viewModel.certImageError {
                            inlineError(error)
                        }
                    }

                    // Work Experience Section
                    docSection("Work Experience", icon: "briefcase.fill") {
                        // Years of experience
                        HStack(spacing: 10) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text("Years of Experience")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Stepper("\(viewModel.yearsOfExperience) yrs", value: $viewModel.yearsOfExperience, in: 0...40)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)

                        // Specialization chips
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Specializations")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            FlowLayout(spacing: 8) {
                                ForEach(Specialization.allCases) { spec in
                                    chipButton(spec)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
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
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.3).tint(.orange)
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
        .animation(.easeInOut(duration: 0.2), value: viewModel.page2ValidationAttempted)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
    }

    // MARK: - Chip Button

    private func chipButton(_ spec: Specialization) -> some View {
        let isSelected = viewModel.selectedSpecializations.contains(spec)
        return Button { viewModel.toggleSpecialization(spec) } label: {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(spec.rawValue)
                    .font(.caption)
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.orange : Color.clear,
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.orange : Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Image Upload

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
                    Button { onImageSelected(nil) } label: {
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
                            await MainActor.run { onImageSelected(uiImage) }
                        }
                        await MainActor.run { pickerItem.wrappedValue = nil }
                    }
                }
            }
        }
    }

    // MARK: - Bottom

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            Button { viewModel.goBack() } label: {
                Text("Back")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .frame(maxWidth: .infinity)

            Button { Task { await viewModel.submitProfile() } } label: {
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

    private func docSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
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
            VStack(spacing: 10) { content() }
        }
    }

    private func validatedField(icon: String, placeholder: String, text: Binding<String>, error: String?, autocap: TextInputAutocapitalization = .never) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                TextField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(autocap)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(error != nil ? .red.opacity(0.5) : .clear, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)

            if let error {
                inlineError(error)
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
