import SwiftUI

struct LoginView: View {
    private enum Field: Hashable { case email, password }

    @State private var viewModel = LoginViewModel()
    @State private var cardAppeared = false
    @State private var showForgotPassword = false

    @State private var twoFactorContext: TwoFactorContext?
    @State private var twoFactorVM: TwoFactorViewModel?
    @State private var showTwoFactor = false
    @FocusState private var focusedField: Field?

    var body: some View {
        ZStack {
            loginContentLayer

            if showTwoFactor, let vm = twoFactorVM {
                TwoFactorView(viewModel: vm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showTwoFactor)
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.25)) {
                cardAppeared = true
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .onChange(of: viewModel.authState) { _, newState in
            switch newState {
            case .requiresTwoFactor(let ctx):
                twoFactorContext = ctx
                twoFactorVM = TwoFactorViewModel(
                    context: ctx,
                    service: viewModel.otpService,
                    onVerified: {
                        // CRITICAL FIX: do NOT set showDestination = true here.
                        // Previously this fired LoginView's fullScreenCover which stacked
                        // a second copy of the dashboard on top of ContentView's dashboard,
                        // burying the BiometricEnrollmentSheet underneath the cover so it
                        // was never visible to the user.
                        //
                        // completeAuthentication() sets isAuthenticated = true.
                        // ContentView observes this change and routes to the correct
                        // destination cleanly — no separate navigation from LoginView needed.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showTwoFactor = false
                            twoFactorVM = nil
                            AuthManager.shared.completeAuthentication()
                        }
                    },
                    onCancelled: {
                        showTwoFactor = false
                        twoFactorContext = nil
                        twoFactorVM = nil
                        viewModel.twoFactorCancelled()
                    }
                )
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
                focusedField = nil
                showTwoFactor = true

            default: break
            }
        }
    }

    // MARK: - Root Layer

    private var loginContentLayer: some View {
        ZStack {
            // ── Background ──────────────────────────────────────────────
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            // ── Error banner – floats at the very top ───────────────────
            VStack {
                if let error = viewModel.errorMessage {
                    errorBanner(message: error)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .animation(.spring(duration: 0.4, bounce: 0.2), value: viewModel.errorMessage)
            .zIndex(10)

            // ── Loading dim ─────────────────────────────────────────────
            if viewModel.isLoading {
                loadingOverlay.zIndex(20)
            }

            // ── Scrollable form ─────────────────────────────────────────
            VStack(spacing: 0) {
                Spacer(minLength: 72)
                headerSection
                    .padding(.bottom, 36)
                formSection
                    .scaleEffect(cardAppeared ? 1 : 0.94)
                    .opacity(cardAppeared ? 1 : 0)
                Spacer(minLength: 80)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image("sierra")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(spacing: 6) {
                Text("Sierra")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color(.label))

                Text("Sign in to your account")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 16) {
            // Email + Password card
            VStack(spacing: 0) {
                // Email row
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color(.systemOrange))
                            .frame(width: 24)
                        
                        TextField("Email", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.system(size: 17))
                            .foregroundStyle(Color(.label))
                            .tint(.orange)
                            .focused($focusedField, equals: .email)
                            .accessibilityLabel("Email")
                            .accessibilityHint("Enter your account email address")
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 50)

                    if let error = viewModel.emailError {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(Color(.systemRed))
                            .padding(.leading, 52)
                            .padding(.bottom, 6)
                            .transition(.opacity)
                    }
                }

                Divider()
                    .padding(.leading, 52)

                // Password row
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color(.systemOrange))
                            .frame(width: 24)

                        Group {
                            if viewModel.isPasswordVisible {
                                TextField("Password", text: $viewModel.password)
                            } else {
                                SecureField("Password", text: $viewModel.password)
                            }
                        }
                        .textContentType(.password)
                        .font(.system(size: 17))
                        .foregroundStyle(Color(.label))
                        .tint(.orange)
                        .focused($focusedField, equals: .password)
                        .accessibilityLabel("Password")
                        .accessibilityHint("Enter your password")

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.isPasswordVisible.toggle()
                            }
                        } label: {
                            Image(systemName: viewModel.isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(viewModel.isPasswordVisible ? "Hide password" : "Show password")
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 50)

                    if let error = viewModel.passwordError {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(Color(.systemRed))
                            .padding(.leading, 52)
                            .padding(.bottom, 6)
                            .transition(.opacity)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 20)

            // Forgot password
            Button {
                showForgotPassword = true
            } label: {
                Text("Forgot Password?")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 24)
            .padding(.top, -4)
            .accessibilityLabel("Forgot Password")

            // Sign In
            Button {
                dismissKeyboard()
                Task { await viewModel.signIn() }
            } label: {
                Text("Sign In")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(.systemOrange))
                    .clipShape(Capsule())
            }
            .disabled(viewModel.isLoading)
            .padding(.horizontal, 20)
            .accessibilityLabel("Sign In")

            // Biometric
            if viewModel.showBiometricButton {
                Button {
                    Task { await viewModel.biometricSignIn() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.biometricIcon)
                            .font(.system(size: 20))
                            .symbolRenderingMode(.hierarchical)
                        Text(viewModel.biometricLabel)
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(Color(.systemOrange))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        Color(.systemOrange).opacity(0.09),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .disabled(viewModel.isLoading)
                .padding(.horizontal, 20)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                .accessibilityLabel("Sign in with biometric authentication")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showBiometricButton)
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
            Button { viewModel.dismissError() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .accessibilityLabel("Dismiss error")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            Color(.systemRed),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.orange)
                Text("Signing in…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .padding(32)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
    }

    @MainActor
    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

#Preview {
    LoginView()
}
