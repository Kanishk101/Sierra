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
            // ── Login content layer ──
            loginContentLayer

            // ── 2FA overlay layer — covers everything when active ──
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
        // ── Dashboard (fullScreenCover) ──
        // Only shown after 2FA success OR biometric success
        .fullScreenCover(isPresented: $showDestination) {
            if let dest = resolvedDestination {
                destinationView(for: dest)
            }
        }
        // ── Forgot Password (sheet) ──
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        // ── React to authState changes ──
        .onChange(of: viewModel.authState) { _, newState in
            #if DEBUG
            print("👁 [LoginView.onChange] authState fired: \(newState)")
            #endif
            switch newState {
            case .requiresTwoFactor(let ctx):
                // Credential login succeeded → show 2FA screen
                // Do NOT show dashboard — 2FA must complete first
                twoFactorContext = ctx
                // Create the VM once and store it — never recreate inline
                twoFactorVM = TwoFactorViewModel(
                    context: ctx,
                    service: viewModel.otpService,   // injects SupabaseOTPVerificationService
                    onVerified: { [self] in
                        #if DEBUG
                        print("🔐 [LoginView.onVerified] 2FA verified — completing auth")
                        #endif
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // Dismiss 2FA overlay
                            showTwoFactor = false
                            twoFactorVM = nil

                            // Complete authentication (saves session token)
                            AuthManager.shared.completeAuthentication()

                            // Set destination and navigate
                            resolvedDestination = ctx.authDestination
                            showDestination = true
                        }
                    },
                    onCancelled: {
                        // User cancelled 2FA — return to login
                        showTwoFactor = false
                        twoFactorContext = nil
                        twoFactorVM = nil
                        viewModel.twoFactorCancelled()
                    }
                )
                // Dismiss keyboard, then show 2FA overlay
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                showTwoFactor = true

            case .authenticated(let destination):
                // Biometric login / first-login succeeded — navigate directly.
                // ContentView handles the Face ID enrollment prompt on the dashboard.
                resolvedDestination = destination
                showDestination = true

            case .error:
                // Error is displayed via errorMessage computed property
                break

            case .idle, .loading:
                break
            }
        }
    }

    // MARK: - Login Content Layer

    private var loginContentLayer: some View {
        ZStack {
            // Dark navy → deep blue gradient
            LinearGradient(
                colors: [SierraTheme.Colors.summitNavy, SierraTheme.Colors.sierraBlue],
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
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .shadow(color: SierraTheme.Colors.ember.opacity(0.15), radius: 24, y: 8)

                Image(systemName: "truck.box.fill")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(SierraTheme.Colors.ember)
                    .symbolRenderingMode(.hierarchical)
            }

            Text("FleetOS")
                .font(SierraFont.title1)
                .foregroundStyle(SierraTheme.Colors.primaryText)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.xxs)
                .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        }
    }

    // MARK: - Login Card

    private var loginCard: some View {
        VStack(spacing: Spacing.lg) {
            // Email field
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "envelope.fill")
                        .font(SierraFont.subheadline)
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 20)

                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(.plain)
                        .font(SierraFont.bodyText)
                        .foregroundStyle(.white)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, Spacing.md)
                .frame(height: 52)
                .background(
                    .white.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(
                            viewModel.emailError != nil ? SierraTheme.Colors.danger.opacity(0.7) : .white.opacity(0.1),
                            lineWidth: 1
                        )
                )

                if let error = viewModel.emailError {
                    inlineError(error)
                }
            }

            // Password field
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "lock.fill")
                        .font(SierraFont.subheadline)
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
                    .font(SierraFont.bodyText)
                    .foregroundStyle(.white)
                    .textContentType(.password)

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.isPasswordVisible.toggle()
                        }
                    } label: {
                        Image(systemName: viewModel.isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .font(SierraFont.subheadline)
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .padding(.horizontal, Spacing.md)
                .frame(height: 52)
                .background(
                    .white.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(
                            viewModel.passwordError != nil ? SierraTheme.Colors.danger.opacity(0.7) : .white.opacity(0.1),
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
                    .font(SierraFont.body(17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        SierraTheme.Colors.ember,
                        in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    )
            }
            .disabled(viewModel.isLoading)
            .padding(.top, Spacing.xxs)

            // Biometric button — requires: device supports it + user opted in + valid session
            if viewModel.showBiometricButton {
                Button {
                    Task { await viewModel.biometricSignIn() }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: viewModel.biometricIcon)
                            .font(.system(size: 20))
                        Text(viewModel.biometricLabel)
                            .font(SierraFont.subheadline)
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        .white.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
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
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.ember.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(Spacing.xl)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, Spacing.xl)
        .animation(.easeInOut(duration: 0.2), value: viewModel.emailError)
        .animation(.easeInOut(duration: 0.2), value: viewModel.passwordError)
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(SierraFont.bodyText)
            Text(message)
                .font(SierraFont.caption1)
            Spacer()
            Button {
                viewModel.dismissError()
            } label: {
                Image(systemName: "xmark")
                    .font(SierraFont.body(12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .background(
            SierraTheme.Colors.danger.opacity(0.9),
            in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        )
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
    }

    // MARK: - Inline Error

    private func inlineError(_ text: String) -> some View {
        Text(text)
            .font(SierraFont.caption1)
            .foregroundStyle(SierraTheme.Colors.danger.opacity(0.9))
            .padding(.leading, Spacing.xxs)
            .transition(.opacity)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.white)
                Text("Authenticating…")
                    .font(SierraFont.caption1)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(Spacing.xxl)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
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
