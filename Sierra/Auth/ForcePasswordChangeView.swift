import SwiftUI


struct ForcePasswordChangeView: View {
    @State private var viewModel = ForcePasswordChangeViewModel()
    @State private var appeared  = false

    var body: some View {
        ZStack {
            // Background — matches ForgotPasswordView / LoginView exactly
            LinearGradient(
                colors: [SierraTheme.Colors.summitNavy, SierraTheme.Colors.sierraBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer(minLength: 60)

                        // ── Header ──
                        Image(systemName: "lock.rotation.fill")
                            .font(.system(size: 50, weight: .light))
                            .foregroundStyle(SierraTheme.Colors.ember)
                            .symbolRenderingMode(.hierarchical)

                        VStack(spacing: 8) {
                            Text("Set Your Password")
                                .font(SierraFont.title2)
                                .foregroundStyle(.white)

                            Text("Create a strong password — you'll use it to sign in going forward.")
                                .font(SierraFont.subheadline)
                                .foregroundStyle(.white.opacity(0.55))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }

                        // ── Form card ──
                        formCard
                            .scaleEffect(appeared ? 1 : 0.95)
                            .opacity(appeared ? 1 : 0)

                        Spacer(minLength: 40)
                    }
                    .frame(minHeight: geo.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            if viewModel.isLoading { loadingOverlay }
        }
        .interactiveDismissDisabled()
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.25)) { appeared = true }
        }
        // Navigate to role-specific destination after password change
        .fullScreenCover(isPresented: $viewModel.completed) {
            ZStack {
                SierraTheme.Colors.appBackground.ignoresSafeArea()
                if let dest = viewModel.nextDestination {
                    destinationView(for: dest)
                }
            }
        }
        .onChange(of: viewModel.readyToNavigate) { _, ready in
            if ready { viewModel.completed = true }
        }
    }

    // ─────────────────────────────────────
    // MARK: - Form Card
    // ─────────────────────────────────────

    private var formCard: some View {
        VStack(spacing: 16) {

            // Current Password
            VStack(alignment: .leading, spacing: 6) {
                passwordField("Current Password",
                              text: $viewModel.currentPassword,
                              isVisible: $viewModel.isCurrentPasswordVisible)
                if let err = viewModel.currentPasswordError {
                    errorLabel(err)
                }
            }

            Divider().background(.white.opacity(0.08))

            // New Password + strength
            VStack(alignment: .leading, spacing: 8) {
                passwordField("New Password",
                              text: $viewModel.newPassword,
                              isVisible: $viewModel.isNewPasswordVisible)

                if !viewModel.newPassword.isEmpty {
                    PasswordStrengthView(password: viewModel.newPassword)
                }
            }

            // Confirm Password
            VStack(alignment: .leading, spacing: 6) {
                passwordField("Confirm New Password",
                              text: $viewModel.confirmPassword,
                              isVisible: $viewModel.isConfirmPasswordVisible)
                if let err = viewModel.confirmPasswordError {
                    errorLabel(err)
                }
            }

            // General error (e.g. same-as-old)
            if let err = viewModel.errorMessage {
                Text(err)
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            // Submit button
            Button {
                Task { await viewModel.setNewPassword() }
            } label: {
                Text("Update Password")
                    .font(SierraFont.body(17, weight: .semibold))
                    .foregroundStyle(viewModel.canSubmit ? .white : .white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        viewModel.canSubmit ? SierraTheme.Colors.ember : Color.gray.opacity(0.25),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            .disabled(!viewModel.canSubmit)
            .animation(.easeInOut(duration: 0.2), value: viewModel.canSubmit)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    // ─────────────────────────────────────
    // MARK: - Password Field (matches ForgotPasswordView style)
    // ─────────────────────────────────────

    private func passwordField(
        _ placeholder: String,
        text: Binding<String>,
        isVisible: Binding<Bool>
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(SierraFont.caption1)
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
            .font(SierraFont.bodyText)
            .foregroundStyle(.white)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            Button {
                isVisible.wrappedValue.toggle()
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.4))
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

    // ─────────────────────────────────────
    // MARK: - Error Label
    // ─────────────────────────────────────

    private func errorLabel(_ text: String) -> some View {
        Text(text)
            .font(SierraFont.caption2)
            .foregroundStyle(SierraTheme.Colors.danger.opacity(0.9))
            .padding(.leading, 4)
            .transition(.opacity)
    }

    // ─────────────────────────────────────
    // MARK: - Loading Overlay
    // ─────────────────────────────────────

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.white)
                Text("Updating password…")
                    .font(SierraFont.caption1)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .transition(.opacity)
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
