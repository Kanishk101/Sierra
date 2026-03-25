import SwiftUI

struct LoginView: View {
    private enum Field: Hashable { case email, password }
    private struct TwoFactorRoute: Identifiable {
        let id = UUID()
        let viewModel: TwoFactorViewModel
    }

    @State private var viewModel = LoginViewModel()
    @State private var showForgotPassword = false
    @State private var twoFactorRoute: TwoFactorRoute?
    @FocusState private var focusedField: Field?

    var body: some View {
        ZStack {
            SierraTheme.Colors.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 56)
                    headerSection
                    formSection
                    actionsSection
                    if viewModel.showBiometricButton {
                        biometricButton
                    }
                    Spacer(minLength: 32)
                }
                .containerRelativeFrame(.vertical, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .onTapGesture { dismissKeyboard() }
        .sheet(isPresented: $showForgotPassword) {
            NavigationStack { ForgotPasswordView() }
                .presentationDetents([.large])
        }
        .fullScreenCover(item: $twoFactorRoute) { route in
            NavigationStack { TwoFactorView(viewModel: route.viewModel) }
                .interactiveDismissDisabled(true)
        }
        .onChange(of: viewModel.authState) { _, newState in
            switch newState {
            case .requiresTwoFactor(let ctx):
                let vm = TwoFactorViewModel(
                    context: ctx,
                    service: viewModel.otpService,
                    onVerified: {
                        twoFactorRoute = nil
                        AuthManager.shared.completeAuthentication()
                    },
                    onCancelled: {
                        twoFactorRoute = nil
                        viewModel.twoFactorCancelled()
                    }
                )
                dismissKeyboard()
                twoFactorRoute = TwoFactorRoute(viewModel: vm)
            default:
                break
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            Image("sierra")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text("Sierra")
                .font(SierraFont.body(34, weight: .bold))
                .foregroundStyle(SierraTheme.Colors.primaryText)

            Text("Sign in to your account")
                .font(SierraFont.subheadline)
                .foregroundStyle(SierraTheme.Colors.secondaryText)
        }
    }

    private var formSection: some View {
        VStack(spacing: 20) {
            SierraTextField(
                label: "Email",
                placeholder: "Enter your email",
                text: $viewModel.email,
                style: .native,
                keyboardType: .emailAddress,
                leadingIcon: "envelope.fill",
                errorMessage: viewModel.emailError,
                maxLength: 100
            )
            .textContentType(.emailAddress)
            .focused($focusedField, equals: .email)

            SierraTextField(
                label: "Password",
                placeholder: "Enter your password",
                text: $viewModel.password,
                style: .native,
                leadingIcon: "lock.fill",
                errorMessage: viewModel.passwordError,
                isSecure: true,
                maxLength: 128
            )
            .textContentType(.password)
            .focused($focusedField, equals: .password)

            Button("Forgot Password?") {
                showForgotPassword = true
            }
            .font(SierraFont.subheadline)
            .foregroundStyle(SierraTheme.Colors.granite)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 24)
    }

    private var actionsSection: some View {
        VStack(spacing: 16) {
            SierraButton.primary("Sign In", isLoading: viewModel.isLoading) {
                dismissKeyboard()
                Task { await viewModel.signIn() }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(SierraFont.footnote)
                    .foregroundStyle(SierraTheme.Colors.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 24)
    }

    private var biometricButton: some View {
        Button {
            Task { await viewModel.biometricSignIn() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: viewModel.biometricIcon)
                    .font(.system(size: 22))
                Text(viewModel.biometricLabel)
                    .font(SierraFont.subheadline)
            }
            .foregroundStyle(SierraTheme.Colors.ember)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                SierraTheme.Colors.ember.opacity(0.1),
                in: Capsule()
            )
        }
        .disabled(viewModel.isLoading)
        .padding(.horizontal, 24)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().tint(SierraTheme.Colors.ember)
                Text("Signing in...")
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.granite)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        }
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
