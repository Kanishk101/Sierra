import SwiftUI


struct DriverProfilePage1View: View {
    @Bindable var viewModel: DriverProfileViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 4) {
                        Text("Personal Details")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Tell us about yourself")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    // Basic Info Section
                    formSection("Basic Information") {
                        fieldRow(icon: "person.fill", placeholder: "First Name", text: $viewModel.firstName, error: viewModel.firstNameError, autocap: .words)
                        fieldRow(icon: "person.fill", placeholder: "Last Name", text: $viewModel.lastName, error: viewModel.lastNameError, autocap: .words)

                        // Date of Birth
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 10) {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text("Date of Birth")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                DatePicker("", selection: $viewModel.dateOfBirth, in: ...viewModel.maxDateOfBirth, displayedComponents: .date)
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                        }

                        // Gender
                        HStack(spacing: 10) {
                            Image(systemName: "person.crop.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text("Gender")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("", selection: $viewModel.gender) {
                                ForEach(Gender.allCases, id: \.self) {
                                    Text($0.rawValue).tag($0)
                                }
                            }
                            .tint(.primary)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                    }

                    // Contact Section
                    formSection("Contact Information") {
                        fieldRow(icon: "phone.fill", placeholder: "Phone Number", text: $viewModel.phoneNumber, error: viewModel.phoneError, keyboard: .phonePad)

                        // Address
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                    .padding(.top, 14)

                                VStack(alignment: .leading, spacing: 4) {
                                    TextEditor(text: $viewModel.address)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .scrollContentBackground(.hidden)
                                        .frame(minHeight: 72)
                                        .overlay(alignment: .topLeading) {
                                            if viewModel.address.isEmpty {
                                                Text("Address (optional)")
                                                    .font(.subheadline)
                                                    .foregroundStyle(.tertiary)
                                                    .padding(.top, 8)
                                            }
                                        }
                                        .onChange(of: viewModel.address) {
                                            if viewModel.address.count > viewModel.addressMaxChars {
                                                viewModel.address = String(viewModel.address.prefix(viewModel.addressMaxChars))
                                            }
                                        }

                                    HStack {
                                        Spacer()
                                        Text("\(viewModel.addressCharCount)/\(viewModel.addressMaxChars)")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                        }
                    }

                    // Emergency Contact Section
                    formSection("Emergency Contact") {
                        fieldRow(icon: "person.crop.circle.badge.exclamationmark", placeholder: "Contact Name", text: $viewModel.emergencyContactName, error: viewModel.emergencyNameError, autocap: .words)
                        fieldRow(icon: "phone.badge.waveform.fill", placeholder: "Contact Phone", text: $viewModel.emergencyContactPhone, error: viewModel.emergencyPhoneError, keyboard: .phonePad)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .scrollDismissesKeyboard(.interactively)

            // Next button
            nextButton
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.page1ValidationAttempted)
    }

    // MARK: - Next Button

    private var nextButton: some View {
        Button {
            _ = viewModel.validateAndAdvance()
        } label: {
            Text("Next")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(Color(.systemBackground).shadow(.drop(color: .black.opacity(0.06), radius: 8, y: -4)))
    }

    // MARK: - Helpers

    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 10) {
                content()
            }
        }
    }

    private func fieldRow(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        error: String? = nil,
        keyboard: UIKeyboardType = .default,
        autocap: TextInputAutocapitalization = .never
    ) -> some View {
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
                    .keyboardType(keyboard)
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
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red.opacity(0.85))
                    .padding(.leading, 4)
                    .transition(.opacity)
            }
        }
    }
}

#Preview {
    DriverProfilePage1View(viewModel: DriverProfileViewModel())
}
