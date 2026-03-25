import SwiftUI

struct DriverProfilePage1View: View {
    @Bindable var viewModel: DriverProfileViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Personal Details")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(SierraTheme.Colors.primaryText)
                        Text("Tell us about yourself to complete your profile")
                            .font(SierraFont.caption1)
                            .foregroundStyle(SierraTheme.Colors.secondaryText)
                    }
                    .padding(.top, 16)

                    // Basic Info Section
                    formSection("Basic Information") {
                        SierraTextField(
                            label: "First Name",
                            placeholder: "Enter first name",
                            text: $viewModel.firstName,
                            style: .native,
                            leadingIcon: "person.fill",
                            errorMessage: viewModel.firstNameError,
                            maxLength: 50
                        )

                        SierraTextField(
                            label: "Last Name",
                            placeholder: "Enter last name",
                            text: $viewModel.lastName,
                            style: .native,
                            leadingIcon: "person.fill",
                            errorMessage: viewModel.lastNameError,
                            maxLength: 50
                        )

                        // Date of Birth
                        VStack(alignment: .leading, spacing: 10) {
                            Text("DATE OF BIRTH")
                                .font(SierraFont.caption2.weight(.bold))
                                .foregroundStyle(SierraTheme.Colors.secondaryText)
                                .tracking(0.5)

                            HStack(spacing: 12) {
                                Image(systemName: "calendar")
                                    .font(.subheadline)
                                    .foregroundStyle(SierraTheme.Colors.secondaryText)
                                    .frame(width: 24)
                                
                                Text("Select Date")
                                    .font(SierraFont.body(16))
                                    .foregroundStyle(SierraTheme.Colors.primaryText)
                                
                                Spacer()
                                
                                DatePicker("", selection: $viewModel.dateOfBirth, in: ...viewModel.maxDateOfBirth, displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(SierraTheme.Colors.ember)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 54)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                            .sierraShadow(SierraTheme.Shadow.card)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Date of Birth")

                        // Gender
                        VStack(alignment: .leading, spacing: 10) {
                            Text("GENDER")
                                .font(SierraFont.caption2.weight(.bold))
                                .foregroundStyle(SierraTheme.Colors.secondaryText)
                                .tracking(0.5)

                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(SierraTheme.Colors.secondaryText)
                                    .frame(width: 24)
                                
                                Text("Select Gender")
                                    .font(SierraFont.body(16))
                                    .foregroundStyle(SierraTheme.Colors.primaryText)
                                
                                Spacer()
                                
                                Picker("", selection: $viewModel.gender) {
                                    ForEach(Gender.allCases, id: \.self) {
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
                        .accessibilityLabel("Gender")
                    }

                    // Contact Section
                    formSection("Contact Information") {
                        SierraTextField(
                            label: "Phone Number",
                            placeholder: "Enter mobile number",
                            text: $viewModel.phoneNumber,
                            style: .native,
                            keyboardType: .phonePad,
                            leadingIcon: "phone.fill",
                            errorMessage: viewModel.phoneError,
                            maxLength: 10,
                            filterDigitsOnly: true
                        )

                        // Address
                        VStack(alignment: .leading, spacing: 10) {
                            Text("RESIDENTIAL ADDRESS")
                                .font(SierraFont.caption2.weight(.bold))
                                .foregroundStyle(SierraTheme.Colors.secondaryText)
                                .tracking(0.5)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "location.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(SierraTheme.Colors.secondaryText)
                                        .frame(width: 24)
                                        .padding(.top, 12)

                                    TextEditor(text: $viewModel.address)
                                        .font(SierraFont.body(16))
                                        .foregroundStyle(SierraTheme.Colors.primaryText)
                                        .scrollContentBackground(.hidden)
                                        .frame(minHeight: 80)
                                        .onChange(of: viewModel.address) { _, newValue in
                                            if newValue.count > viewModel.addressMaxChars {
                                                viewModel.address = String(newValue.prefix(viewModel.addressMaxChars))
                                            }
                                        }
                                        .overlay(alignment: .topLeading) {
                                            if viewModel.address.isEmpty {
                                                Text("Enter your full address")
                                                    .font(SierraFont.body(16))
                                                    .foregroundStyle(SierraTheme.Colors.secondaryText)
                                                    .padding(.top, 8)
                                                    .allowsHitTesting(false)
                                            }
                                        }
                                }
                                
                                HStack {
                                    Spacer()
                                    Text("\(viewModel.addressCharCount)/\(viewModel.addressMaxChars)")
                                        .font(SierraFont.caption1)
                                        .foregroundStyle(SierraTheme.Colors.secondaryText)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                            .sierraShadow(SierraTheme.Shadow.card)
                        }
                    }

                    // Emergency Contact Section
                    formSection("Emergency Contact") {
                        SierraTextField(
                            label: "Contact Name",
                            placeholder: "Full name",
                            text: $viewModel.emergencyContactName,
                            style: .native,
                            leadingIcon: "person.crop.circle.badge.exclamationmark",
                            errorMessage: viewModel.emergencyNameError,
                            maxLength: 50
                        )

                        SierraTextField(
                            label: "Contact Phone",
                            placeholder: "Mobile number",
                            text: $viewModel.emergencyContactPhone,
                            style: .native,
                            keyboardType: .phonePad,
                            leadingIcon: "phone.badge.waveform.fill",
                            errorMessage: viewModel.emergencyPhoneError,
                            maxLength: 10,
                            filterDigitsOnly: true
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)

            // Next button
            VStack(spacing: 0) {
                Divider().background(SierraTheme.Colors.cloud.opacity(0.5))
                SierraButton.primary("Continue") {
                    _ = viewModel.validateAndAdvance()
                }
                .padding(24)
                .background(SierraTheme.Colors.appBackground)
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: viewModel.page1ValidationAttempted)
    }

    // MARK: - Helpers

    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(SierraFont.caption1.weight(.bold))
                .foregroundStyle(SierraTheme.Colors.ember)
                .tracking(0.5)

            VStack(spacing: 20) {
                content()
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    DriverProfilePage1View(viewModel: DriverProfileViewModel())
}
