import SwiftUI

struct LoginView: View {
    @State private var viewModel = LoginViewModel()
    @State private var cardAppeared = false
    @State private var showForgotPassword = false

    // 2FA overlay
    @State private var twoFactorContext: TwoFactorContext?
    @State private var twoFactorVM: TwoFactorViewModel?
    @State private var showTwoFactor = false

    // Dashboard
    @State private var resolvedDestination: AuthDestination?
    @State private var showDestination = false

    // Returning user — used to conditionally show Face ID button
    @State private var lastProfile: SecureSessionStore.StoredProfile?

    var body: some View {
        ZStack {
            // Login content layer
            loginContentLayer

            // 2FA overlay layer — covers everything when active
            if showTwoFactor, let vm = twoFactorVM {
                TwoFactorView(viewModel: vm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showTwoFactor)
        .onAppear {
            lastProfile = SecureSessionStore.shared.loadLastProfile()
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) {
                cardAppeared = true
            }
        }
        // Dashboard (fullScreenCover)
        .fullScreenCover(isPresented: $showDestination) {
            if let dest = resolvedDestination {
                destinationView(for: dest)
                    .environment(AppDataStore.shared)
                    .environment(AuthManager.shared)
            }
        }
        // Forgot Password (sheet)
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        // React to authState changes
        .onChange(of: viewModel.authState) { _, newState in
            #if DEBUG
            print("\u{1F441} [LoginView.onChange] authState fired: \(newState)")
            #endif
            switch newState {
            case .requiresTwoFactor(let ctx):
                twoFactorContext = ctx
                twoFactorVM = TwoFactorViewModel(
                    context: ctx,
                    service: viewModel.otpService,
                    onVerified: { [self] in
                        #if DEBUG
                        print("\u{1F510} [LoginView.onVerified] 2FA verified — completing auth")
                        #endif
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showTwoFactor = false
                            twoFactorVM = nil
                            AuthManager.shared.completeAuthentication()
                            resolvedDestination = ctx.authDestination
                            showDestination = true
                        }
                    },
                    onCancelled: {
                        showTwoFactor = false
                        twoFactorContext = nil
                        twoFactorVM = nil
                        viewModel.twoFactorCancelled()
                    }
                )
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                showTwoFactor = true

            case .authenticated(let destination):
                resolvedDestination = destination
                showDestination = true

            case .error:
                break

            case .idle, .loading:
                break
            }
        }
    }

    // MARK: - Login Content Layer

    private var loginContentLayer: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack {
                if let error = viewModel.errorMessage {
                    errorBanner(message: error)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .animation(.spring(duration: 0.4, bounce: 0.2), value: viewModel.errorMessage)
            .zIndex(10)

            if viewModel.isLoading {
                loadingOverlay
                    .zIndex(20)
            }

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 80)
                        headerSection
                            .padding(.bottom, 40)
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
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "truck.box.fill")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(.orange)
                    .symbolRenderingMode(.hierarchical)
            }

            Text("FleetOS")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Login Card

    private var loginCard: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: "envelope.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)

                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(
                    Color(.tertiarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            viewModel.emailError != nil ? Color.red.opacity(0.7) : Color(.separator),
                            lineWidth: 1
                        )
                )

                if let error = viewModel.emailError {
                    inlineError(error)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)

                    Group {
                        if viewModel.isPasswordVisible {
                            TextField("Password", text: $viewModel.password)
                        } else {
                            SecureField("Password", text: $viewModel.password)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textContentType(.password)

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.isPasswordVisible.toggle()
                        }
                    } label: {
                        Image(systemName: viewModel.isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(
                    Color(.tertiarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            viewModel.passwordError != nil ? Color.red.opacity(0.7) : Color(.separator),
                            lineWidth: 1
                        )
                )

                if let error = viewModel.passwordError {
                    inlineError(error)
                }
            }

            Button {
                Task { await viewModel.signIn() }
            } label: {
                Text("Sign In")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        Color.orange,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            .disabled(viewModel.isLoading)
            .padding(.top, 4)

            if viewModel.showBiometricButton {
                Button {
                    Task { await viewModel.biometricSignIn() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.biometricIcon)
                            .font(.system(size: 20))
                        Text(viewModel.biometricLabel)
                            .font(.subheadline)
                    }
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        Color.orange.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
                    )
                }
                .disabled(viewModel.isLoading)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            Button {
                showForgotPassword = true
            } label: {
                Text("Forgot Password?")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.2), value: viewModel.emailError)
        .animation(.easeInOut(duration: 0.2), value: viewModel.passwordError)
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.body)
            Text(message)
                .font(.caption)
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
            .font(.caption2)
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
                    .tint(.orange)
                Text("Authenticating\u{2026}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
    }

    // MARK: - Routing

    @ViewBuilder
    private func destinationView(for destination: AuthDestination) -> some View {
        switch destination {
        case .fleetManagerDashboard:  AdminDashboardView()
        case .changePassword:         ForcePasswordChangeView()
        case .driverOnboarding:       DriverProfileSetupView()
        case .maintenanceOnboarding:  MaintenanceProfileSetupView()
        case .pendingApproval:        PendingApprovalView()
        case .rejected:               RejectedView()
        case .driverDashboard:        DriverTabView()
        case .maintenanceDashboard:   MaintenanceDashboardView()
        }
    }
}

#Preview {
    LoginView()
}
