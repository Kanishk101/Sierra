import SwiftUI

struct LoginView: View {
    @State private var viewModel = LoginViewModel()
    @State private var cardAppeared = false
    @State private var showForgotPassword = false

    @State private var twoFactorContext: TwoFactorContext?
    @State private var twoFactorVM: TwoFactorViewModel?
    @State private var lastProfile: SecureSessionStore.StoredProfile?
    @State private var navPath: [String] = []

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                loginContentLayer
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { twoFactorVM != nil },
                    set: { if !$0 { twoFactorVM = nil } }
                )
            ) {
                if let vm = twoFactorVM {
                    TwoFactorView(viewModel: vm)
                }
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
            .onAppear {
                lastProfile = SecureSessionStore.shared.loadLastProfile()
                withAnimation(.spring(duration: 0.6, bounce: 0.3)) {
                    cardAppeared = true
                }
            }
            .onChange(of: viewModel.authState) { _, newState in
                switch newState {
                case .requiresTwoFactor(let ctx):
                    twoFactorContext = ctx
                    twoFactorVM = TwoFactorViewModel(
                        context: ctx,
                        service: viewModel.otpService,
                        onVerified: { [self] in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                twoFactorVM = nil
                                AuthManager.shared.completeAuthentication()
                            }
                        },
                        onCancelled: {
                            twoFactorContext = nil
                            twoFactorVM = nil
                            viewModel.twoFactorCancelled()
                        }
                    )
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                case .authenticated:
                    break // Handled by ContentView observing AuthManager

                case .error, .idle, .loading:
                    break
                }
            }
        }
    }

    // MARK: - Login Content Layer

    private var loginContentLayer: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            if viewModel.isLoading {
                loadingOverlay.zIndex(20)
            }

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 72)
                        headerSection
                            .padding(.bottom, 32)
                        loginCard
                            .scaleEffect(cardAppeared ? 1 : 0.94)
                            .opacity(cardAppeared ? 1 : 0)
                        Spacer(minLength: 48)
                    }
                    .frame(minHeight: geo.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "car.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(Color(.systemOrange))
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 4) {
                Text("FleetOS")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.primary)

                Text("Fleet Management Platform")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.secondary)
            }
        }
    }

    // MARK: - Login Card

    private var loginCard: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                // Error banner inline
                if let error = viewModel.errorMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 15))
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                        Spacer()
                        Button {
                            viewModel.dismissError()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground))
                    Divider()
                }

                // Email field
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(.label))
                            .frame(width: 20)
                        TextField("Email", text: $viewModel.email)
                            .textFieldStyle(.plain)
                            .font(.system(size: 17))
                            .foregroundStyle(Color(.label))
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    if let error = viewModel.emailError {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                }

                Divider().padding(.leading, 52)

                // Password field
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(.label))
                            .frame(width: 20)
                        Group {
                            if viewModel.isPasswordVisible {
                                TextField("Password", text: $viewModel.password)
                            } else {
                                SecureField("Password", text: $viewModel.password)
                            }
                        }
                        .textFieldStyle(.plain)
                        .font(.system(size: 17))
                        .foregroundStyle(Color(.label))
                        .textContentType(.password)
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.isPasswordVisible.toggle()
                            }
                        } label: {
                            Image(systemName: viewModel.isPasswordVisible
                                  ? "eye.slash" : "eye")
                                .font(.system(size: 15))
                                .foregroundStyle(Color(.label))
                        }
                        .padding(.trailing, 4)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    if let error = viewModel.passwordError {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                }
            }
            .background(
                Color(.systemBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 0.5)
            )
            .padding(.horizontal, 20)

            // Forgot Password link
            HStack {
                Button {
                    showForgotPassword = true
                } label: {
                    Text("Forgot Password?")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 2)

            // Buttons
            VStack(spacing: 12) {
                Button {
                    Task { await viewModel.signIn() }
                } label: {
                    Text("Sign In")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            Color(.systemOrange),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                }
                .disabled(viewModel.isLoading)
                .padding(.horizontal, 20)

                if viewModel.showBiometricButton {
                    Button {
                        Task { await viewModel.biometricSignIn() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.biometricIcon)
                                .font(.system(size: 18))
                            Text(viewModel.biometricLabel)
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundStyle(Color(.systemOrange))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            Color(.systemOrange).opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                    }
                    .disabled(viewModel.isLoading)
                    .padding(.horizontal, 20)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(.top, 20)
        }
    }

    // MARK: - Loading Overlay

    var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(Color(.systemOrange))
                Text("Signing in…")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.primary)
            }
            .padding(28)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
    }
}

#Preview {
    LoginView()
}
