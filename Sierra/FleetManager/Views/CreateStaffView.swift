import SwiftUI


struct CreateStaffView: View {
    @State private var viewModel = CreateStaffViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.showSuccess {
                    successView
                } else {
                    roleSelectionStep
                }
            }
            .navigationTitle("Add Staff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Step 1: Role Selection

    private var roleSelectionStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 6) {
                        Text("Select a Role")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Choose the role for the new staff member")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    // Role cards
                    HStack(spacing: 14) {
                        roleCard(
                            role: .driver,
                            icon: "car.fill",
                            title: "Driver",
                            description: "Can manage trips, log fuel, and report vehicle issues"
                        )
                        roleCard(
                            role: .maintenancePersonnel,
                            icon: "wrench.fill",
                            title: "Maintenance",
                            description: "Can manage work orders, log repairs, and handle breakdowns"
                        )
                    }
                    .padding(.horizontal, 20)

                    // Step 2 content appears below when role is selected
                    if viewModel.isRoleSelected {
                        detailsForm
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .animation(.spring(duration: 0.4, bounce: 0.15), value: viewModel.isRoleSelected)

            // Bottom button
            if viewModel.isRoleSelected {
                submitButton
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                continueButton
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .overlay {
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isLoading)
    }

    // MARK: - Role Card

    private func roleCard(role: UserRole, icon: String, title: String, description: String) -> some View {
        let isSelected = viewModel.selectedRole == role

        return Button {
            withAnimation(.spring(duration: 0.3)) {
                viewModel.selectedRole = role
            }
        } label: {
            VStack(spacing: 14) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(SierraFont.scaled(32, weight: .light))
                        .foregroundStyle(isSelected ? .orange : .secondary)
                        .frame(width: 60, height: 60)
                        .background(
                            (isSelected ? Color.orange : Color.primary).opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(SierraFont.scaled(20))
                            .foregroundStyle(.orange)
                            .offset(x: 6, y: -6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(title)
                    .font(SierraFont.scaled(16, weight: .bold))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.orange : .clear,
                        lineWidth: 2
                    )
            )
            .shadow(color: .black.opacity(isSelected ? 0.06 : 0.03), radius: isSelected ? 10 : 6, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Details Form

    private var detailsForm: some View {
        VStack(spacing: 20) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: "person.text.rectangle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Staff Details")
                    .font(SierraFont.scaled(16, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)

            VStack(spacing: 14) {
                // Full Name
                VStack(alignment: .leading, spacing: 5) {
                    formField(
                        icon: "person.fill",
                        placeholder: "Full Name",
                        text: $viewModel.fullName
                    )
                    if let error = viewModel.nameError {
                        inlineError(error)
                    }
                }

                // Email
                VStack(alignment: .leading, spacing: 5) {
                    formField(
                        icon: "envelope.fill",
                        placeholder: "Email Address",
                        text: $viewModel.email,
                        keyboard: .emailAddress
                    )
                    if let error = viewModel.emailError {
                        inlineError(error)
                    }
                }
            }
            .padding(.horizontal, 20)

            // Credential preview card
            if !viewModel.email.isEmpty && viewModel.emailError == nil {
                credentialPreviewCard
                    .padding(.horizontal, 20)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }

            // Error banner
            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                }
                .foregroundStyle(.white)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.emailError)
        .animation(.easeInOut(duration: 0.2), value: viewModel.nameError)
        .animation(.spring(duration: 0.3), value: viewModel.errorMessage)
    }

    // MARK: - Credential Preview

    private var credentialPreviewCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope.badge.shield.half.filled.fill")
                .font(SierraFont.scaled(24))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Credential Notification")
                    .font(.caption)
                    .foregroundStyle(.primary)
                Text("An account will be created and login credentials will be emailed to **\(viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines))**")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Buttons

    private var continueButton: some View {
        Button {} label: {
            Text("Continue")
                .font(SierraFont.scaled(17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(true)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private var submitButton: some View {
        Button {
            Task { await viewModel.createStaff() }
        } label: {
            Text("Create & Send Credentials")
                .font(SierraFont.scaled(17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    viewModel.canSubmit ? Color.orange : Color.gray.opacity(0.3),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        }
        .disabled(!viewModel.canSubmit || viewModel.isLoading)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .animation(.easeInOut(duration: 0.2), value: viewModel.canSubmit)
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.green.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(SierraFont.scaled(56))
                    .foregroundStyle(.green)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 8) {
                Text("Staff Created!")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Account created for")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(viewModel.createdStaffName)
                    .font(SierraFont.scaled(17, weight: .semibold))
                    .foregroundStyle(.primary)

                if let role = viewModel.selectedRole {
                    Text(role.displayName)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.1), in: Capsule())
                        .padding(.top, 4)
                }
            }

            // Email delivery result
            if !viewModel.emailDelivered {
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Email delivery failed")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    Text("Share these credentials manually:")
                        .font(.caption).foregroundStyle(.secondary)
                    if let pwd = viewModel.createdTempPassword {
                        VStack(spacing: 4) {
                            Text(viewModel.createdStaffEmail)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)
                            Text(pwd)
                                .font(.system(.caption, design: .monospaced).weight(.bold))
                                .foregroundStyle(.orange)
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 24)
            } else {
                Text("Credentials emailed to \(viewModel.createdStaffEmail)")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(SierraFont.scaled(17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // MARK: - Shared Components

    private func formField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(.primary)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
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
                Text("Creating account…")
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
    CreateStaffView()
}
