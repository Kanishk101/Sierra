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
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App logo
                Image(systemName: "truck.box.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.orange)
                    .padding(.bottom, 6)

                Text("FleetOS")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.bottom, 30)

                // Welcome message
                if let user = AuthManager.shared.currentUser {
                    Text("Welcome back, \(user.name ?? "User")")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 40)
                }

                // Face ID icon button
                biometricButton
                    .scaleEffect(appeared ? 1 : 0.8)
                    .opacity(appeared ? 1 : 0)

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 16)
                        .transition(.opacity)
                }

                // Try Again button (appears after failure)
                if showTryAgain {
                    Button {
                        Task { await attemptBiometric() }
                    } label: {
                        Text("Try Again")
                            .font(.subheadline.weight(.medium))
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

                // Password fallback
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
            // Auto-trigger after 0.4s delay
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
                        .fill(Color.orange.opacity(0.08))
                        .frame(width: 100, height: 100)

                    if isAuthenticating {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(.orange)
                    } else {
                        Image(systemName: biometric.biometricIconName)
                            .font(.system(size: 60))
                            .foregroundStyle(.orange)
                            .symbolEffect(.pulse, isActive: appeared && !showTryAgain)
                    }
                }

                Text("Sign in with \(biometric.biometricDisplayName)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(isAuthenticating)
    }

    // MARK: - Password Fallback

    private var passwordFallbackButton: some View {
        Button {
            // Sign out and route to LoginView
            AuthManager.shared.signOut()
            lifecycle.passwordFallbackUsed()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                Text("Use Password Instead")
                    .font(.subheadline)
            }
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                Color.orange.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.15), lineWidth: 1)
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
            // Success - dismiss lock screen
            lifecycle.biometricUnlocked()
        } catch let error as BiometricError {
            switch error {
            case .userCancelled:
                // Don't show error, just show try again
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
