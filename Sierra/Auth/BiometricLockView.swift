import SwiftUI


/// Full-screen biometric lock overlay.
/// Triggered when the app returns from background after 60s.
struct BiometricLockView: View {

    @State private var appeared = false
    @State private var errorMessage: String?
    @State private var showTryAgain = false
    @State private var isAuthenticating = false

    private let biometric = BiometricManager.shared
    private let lifecycle = AppLifecycleMonitor.shared

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "car.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Color.orange)
                    .padding(.bottom, 6)

                Text("FleetOS")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .padding(.bottom, 30)

                if let user = AuthManager.shared.currentUser {
                    Text("Welcome back, \(user.name ?? "User")")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .padding(.bottom, 40)
                }

                biometricButton
                    .scaleEffect(appeared ? 1 : 0.8)
                    .opacity(appeared ? 1 : 0)

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 16)
                        .transition(.opacity)
                }

                if showTryAgain {
                    Button {
                        Task { await attemptBiometric() }
                    } label: {
                        Text("Try Again")
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                Color.orange,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()

                passwordFallbackButton
                    .opacity(showTryAgain ? 1 : 0.4)
            }
        }
        .interactiveDismissDisabled(true)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .animation(.spring(duration: 0.3), value: showTryAgain)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.25)) {
                appeared = true
            }
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                await attemptBiometric()
            }
        }
    }

    // MARK: - Biometric Button

    private var biometricButton: some View {
        Button {
            Task { await attemptBiometric() }
        } label: {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(width: 100, height: 100)

                    if isAuthenticating {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(Color(.systemOrange))
                    } else {
                        Image(systemName: biometric.biometricIconName)
                            .font(.system(size: 60))
                            .foregroundStyle(Color.orange)
                            .symbolEffect(.pulse, isActive: appeared && !showTryAgain)
                    }
                }

                Text("Sign in with \(biometric.biometricDisplayName)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(isAuthenticating)
    }

    // MARK: - Password Fallback

    private var passwordFallbackButton: some View {
        Button {
            AuthManager.shared.signOut()
            lifecycle.passwordFallbackUsed()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                Text("Use Password Instead")
                    .font(.system(size: 15))
            }
            .foregroundStyle(Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color(.separator), lineWidth: 1)
            )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    // MARK: - Auth Logic

    @MainActor
    private func attemptBiometric() async {
        guard !isAuthenticating else { return }

        isAuthenticating = true
        errorMessage = nil
        showTryAgain = false

        do {
            try await biometric.authenticate(reason: "Unlock FleetOS")
            lifecycle.biometricUnlocked()
        } catch let error as BiometricError {
            switch error {
            case .userCancelled:
                showTryAgain = true
            default:
                errorMessage = error.errorDescription
                showTryAgain = true
            }
        } catch {
            errorMessage = "Authentication failed. Please try again."
            showTryAgain = true
        }

        isAuthenticating = false
    }
}

#Preview {
    BiometricLockView()
}
