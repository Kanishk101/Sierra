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
            Color(.systemGroupedBackground).ignoresSafeArea()

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
                .padding(.top, 4)
            }
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
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.primary)

            Text("Sign in to your account")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var formSection: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .email)
                    .padding(.horizontal, 14)
                    .frame(height: 54)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let error = viewModel.emailError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .padding(.leading, 2)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Group {
                        if viewModel.isPasswordVisible {
                            TextField("Password", text: $viewModel.password)
                        } else {
                            SecureField("Password", text: $viewModel.password)
                        }
                    }
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .password)

                    Button {
                        viewModel.isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: viewModel.isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .frame(height: 54)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let error = viewModel.passwordError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .padding(.leading, 2)
                }
            }

            Button("Forgot Password?") {
                showForgotPassword = true
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
    }

    private var actionsSection: some View {
        VStack(spacing: 14) {
            Button {
                dismissKeyboard()
                Task { await viewModel.signIn() }
            } label: {
                Text("Sign In")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(.systemOrange), in: Capsule())
            }
            .disabled(viewModel.isLoading)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 20)
    }

    private var biometricButton: some View {
        Button {
            Task { await viewModel.biometricSignIn() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: viewModel.biometricIcon)
                    .font(.system(size: 20))
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
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().tint(.orange)
                Text("Signing in...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
