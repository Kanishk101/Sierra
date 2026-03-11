import SwiftUI

/// Accent orange used across the auth flow.
private let accentOrange = Color(red: 1.0, green: 0.584, blue: 0.0) // #FF9500

struct LoginView: View {
    @State private var viewModel = LoginViewModel()
    @State private var cardAppeared = false
    @State private var showTwoFactor = false
    @State private var showForgotPassword = false
    @State private var showDestination = false
    @State private var showBiometricEnrollment = false
    @State private var twoFactorVM: TwoFactorViewModel?

    var body: some View {
        ZStack {
            // Dark navy → deep blue gradient
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "1B3A6B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Error banner — slides in from top
            VStack {
                if let error = viewModel.errorMessage {
                    errorBanner(message: error)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .animation(.spring(duration: 0.4, bounce: 0.2), value: viewModel.errorMessage)
            .zIndex(10)

            // Loading overlay
            if viewModel.isLoading {
                loadingOverlay
                    .zIndex(20)
            }

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 80)

                        // Logo & title
                        headerSection
                            .padding(.bottom, 40)

                        // Login card
                        loginCard
                            .scaleEffect(cardAppeared ? 1 : 0.92)
                            .opacity(cardAppeared ? 1 : 0)

                        Spacer(minLength: 80)
                    }
                    .frame(minHeight: geo.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) {
                cardAppeared = true
            }
        }
        .fullScreenCover(isPresented: $showTwoFactor) {
            if let vm = twoFactorVM {
                TwoFactorView(viewModel: vm)
            }
        }
        .fullScreenCover(isPresented: $showDestination) {
            if let destination = viewModel.authDestination {
                destinationView(for: destination)
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .sheet(isPresented: $showBiometricEnrollment, onDismiss: {
            // After enrollment prompt dismissed, show destination
            showDestination = true
        }) {
            BiometricEnrollmentSheet()
                .presentationDetents([.medium])
        }
        .onChange(of: viewModel.loginSuccess) { _, success in
            guard success else { return }
            // Login succeeded — generate OTP and show 2FA
            AuthManager.shared.generateOTP()
            twoFactorVM = TwoFactorViewModel(
                subtitle: "Enter the code sent to verify your identity.",
                maskedEmail: AuthManager.shared.maskedEmail,
                onVerified: { [self] in
                    showTwoFactor = false
                    // Check if we should prompt for biometric enrollment
                    if BiometricEnrollmentSheet.shouldPrompt() {
                        showBiometricEnrollment = true
                    } else {
                        showDestination = true
                    }
                },
                onCancelled: { [self] in
                    showTwoFactor = false
                    viewModel.loginSuccess = false
                    viewModel.authDestination = nil
                }
            )
            showTwoFactor = true
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .shadow(color: accentOrange.opacity(0.15), radius: 24, y: 8)

                Image(systemName: "truck.box.fill")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(accentOrange)
                    .symbolRenderingMode(.hierarchical)
            }

            Text("FleetOS")
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundStyle(Color(hex: "0D1B2A"))
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - Login Card

    private var loginCard: some View {
        VStack(spacing: 20) {
            // Email field
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 20)

                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(
                    .white.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            viewModel.emailError != nil ? .red.opacity(0.7) : .white.opacity(0.1),
                            lineWidth: 1
                        )
                )

                if let error = viewModel.emailError {
                    inlineError(error)
                }
            }

            // Password field
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 20)

                    Group {
                        if viewModel.isPasswordVisible {
                            TextField("Password", text: $viewModel.password)
                        } else {
                            SecureField("Password", text: $viewModel.password)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .textContentType(.password)

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.isPasswordVisible.toggle()
                        }
                    } label: {
                        Image(systemName: viewModel.isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(
                    .white.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            viewModel.passwordError != nil ? .red.opacity(0.7) : .white.opacity(0.1),
                            lineWidth: 1
                        )
                )

                if let error = viewModel.passwordError {
                    inlineError(error)
                }
            }

            // Sign In button
            Button {
                Task { await viewModel.signIn() }
            } label: {
                Text("Sign In")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        accentOrange,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            .disabled(viewModel.isLoading)
            .padding(.top, 4)

            // Biometric button
            if viewModel.showBiometricButton {
                Button {
                    Task { await viewModel.biometricSignIn() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.biometricIcon)
                            .font(.system(size: 20))
                        Text(viewModel.biometricLabel)
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        .white.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .disabled(viewModel.isLoading)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Forgot Password link
            Button {
                showForgotPassword = true
            } label: {
                Text("Forgot Password?")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(accentOrange.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.2), value: viewModel.emailError)
        .animation(.easeInOut(duration: 0.2), value: viewModel.passwordError)
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
            Text(message)
                .font(.system(size: 14, weight: .medium))
            Spacer()
            Button {
                viewModel.dismissError()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            Color.red.opacity(0.9),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Inline Error

    private func inlineError(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.red.opacity(0.9))
            .padding(.leading, 4)
            .transition(.opacity)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.white)
                Text("Authenticating…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
    }

    // MARK: - Routing

    @ViewBuilder
    private func destinationView(for destination: AuthDestination) -> some View {
        switch destination {
        case .fleetManagerDashboard:  AdminDashboardView()
        case .changePassword:        ForcePasswordChangeView()
        case .driverOnboarding:      DriverProfileSetupView()
        case .maintenanceOnboarding: MaintenanceProfileSetupView()
        case .pendingApproval:       PendingApprovalView()
        case .driverDashboard:       DriverTabView()
        case .maintenanceDashboard:  MaintenanceDashboardView()
        }
    }
}

#Preview {
    LoginView()
}
