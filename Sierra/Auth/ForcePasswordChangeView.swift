import SwiftUI

private let navyDark = Color(hex: "0D1B2A")
private let accentOrange = Color(red: 1.0, green: 0.584, blue: 0.0)

struct ForcePasswordChangeView: View {
    @State private var viewModel = ForcePasswordChangeViewModel()
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "1B3A6B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 40)

                        // Header
                        headerSection
                            .padding(.bottom, 28)

                        // Form card
                        formCard
                            .scaleEffect(appeared ? 1 : 0.93)
                            .opacity(appeared ? 1 : 0)

                        Spacer(minLength: 40)
                    }
                    .frame(minHeight: geo.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            // Loading overlay
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .interactiveDismissDisabled()
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.25)) {
                appeared = true
            }
        }
        .fullScreenCover(isPresented: $viewModel.passwordChanged) {
            if let dest = viewModel.nextDestination {
                destinationView(for: dest)
            }
        }
    }

    // ─────────────────────────────────────
    // MARK: - Header
    // ─────────────────────────────────────

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.rotation.fill")
                .font(.system(size: 50, weight: .light))
                .foregroundStyle(accentOrange)
                .symbolRenderingMode(.hierarchical)

            Text("Set Your New Password")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            Text("For your security, you must set a personal\npassword before continuing.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    // ─────────────────────────────────────
    // MARK: - Form Card
    // ─────────────────────────────────────

    private var formCard: some View {
        VStack(spacing: 18) {
            // Error banner
            if let error = viewModel.errorMessage {
                errorBanner(error)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Current Password
            VStack(alignment: .leading, spacing: 5) {
                passwordField(
                    placeholder: "Current Password",
                    text: $viewModel.currentPassword,
                    isVisible: $viewModel.isCurrentPasswordVisible
                )
                if let error = viewModel.currentPasswordError {
                    inlineError(error)
                }
            }

            // New Password
            VStack(alignment: .leading, spacing: 8) {
                passwordField(
                    placeholder: "New Password",
                    text: $viewModel.newPassword,
                    isVisible: $viewModel.isNewPasswordVisible
                )

                // Strength bar
                if !viewModel.newPassword.isEmpty {
                    strengthBar
                        .transition(.opacity)
                }
            }

            // Requirements checklist
            if !viewModel.newPassword.isEmpty {
                requirementsChecklist
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }

            // Confirm Password
            VStack(alignment: .leading, spacing: 5) {
                passwordField(
                    placeholder: "Confirm New Password",
                    text: $viewModel.confirmPassword,
                    isVisible: $viewModel.isConfirmPasswordVisible
                )
                if let error = viewModel.confirmPasswordError {
                    inlineError(error)
                }
            }

            // Submit button
            Button {
                Task { await viewModel.setNewPassword() }
            } label: {
                Text("Set Password")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(viewModel.canSubmit ? .white : .white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        viewModel.canSubmit ? accentOrange : Color.gray.opacity(0.25),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            .disabled(!viewModel.canSubmit)
            .padding(.top, 4)
            .animation(.easeInOut(duration: 0.2), value: viewModel.canSubmit)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .animation(.easeInOut(duration: 0.25), value: viewModel.newPassword.isEmpty)
        .animation(.easeInOut(duration: 0.2), value: viewModel.currentPasswordError)
        .animation(.easeInOut(duration: 0.2), value: viewModel.confirmPasswordError)
        .animation(.spring(duration: 0.3), value: viewModel.errorMessage)
    }

    // ─────────────────────────────────────
    // MARK: - Strength Bar
    // ─────────────────────────────────────

    private var strengthBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index <= viewModel.strength.rawValue
                              ? viewModel.strength.color : .white.opacity(0.1))
                        .frame(height: 5)
                }
            }

            HStack {
                Text(viewModel.strength.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(viewModel.strength.color)
                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.strength)
    }

    // ─────────────────────────────────────
    // MARK: - Requirements Checklist
    // ─────────────────────────────────────

    private var requirementsChecklist: some View {
        VStack(alignment: .leading, spacing: 6) {
            requirementRow("At least 8 characters", met: viewModel.hasMinLength)
            requirementRow("One uppercase letter", met: viewModel.hasUppercase)
            requirementRow("One number", met: viewModel.hasNumber)
            requirementRow("One special character", met: viewModel.hasSpecialChar)
        }
        .padding(14)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func requirementRow(_ text: String, met: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: 14))
                .foregroundStyle(met ? .green : .white.opacity(0.3))

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(met ? .white.opacity(0.9) : .white.opacity(0.4))
        }
        .animation(.easeInOut(duration: 0.15), value: met)
    }

    // ─────────────────────────────────────
    // MARK: - Shared Components
    // ─────────────────────────────────────

    private func passwordField(
        placeholder: String,
        text: Binding<String>,
        isVisible: Binding<Bool>
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 20)

            Group {
                if isVisible.wrappedValue {
                    TextField(placeholder, text: text)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 16))
            .foregroundStyle(.white)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            Button {
                withAnimation(.easeInOut(duration: 0.12)) {
                    isVisible.wrappedValue.toggle()
                }
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func inlineError(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.red.opacity(0.9))
            .padding(.leading, 4)
            .transition(.opacity)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
            Text(message)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.white)
                Text("Updating password…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
    }

    // ─────────────────────────────────────
    // MARK: - Routing
    // ─────────────────────────────────────

    @ViewBuilder
    private func destinationView(for destination: AuthDestination) -> some View {
        switch destination {
        case .fleetManagerDashboard:  AdminDashboardView()
        case .driverOnboarding:      DriverProfileSetupView()
        case .maintenanceOnboarding: MaintenanceProfileSetupView()
        case .driverDashboard:       DriverTabView()
        case .maintenanceDashboard:  MaintenanceDashboardView()
        case .pendingApproval:       PendingApprovalView()
        case .changePassword:        EmptyView()
        }
    }
}

#Preview {
    ForcePasswordChangeView()
}
