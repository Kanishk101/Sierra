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
            LinearGradient(
                colors: [SierraTheme.Colors.summitNavy, SierraTheme.Colors.sierraBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App logo
                Image(systemName: "truck.box.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(SierraTheme.Colors.ember)
                    .padding(.bottom, 6)

                Text("FleetOS")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.bottom, 30)

                // Welcome message
                if let user = AuthManager.shared.currentUser {
                    Text("Welcome back, \(user.name ?? "User")")
                        .font(SierraFont.body(18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.bottom, 40)
                }

                // Face ID icon button
                biometricButton
                    .scaleEffect(appeared ? 1 : 0.8)
                    .opacity(appeared ? 1 : 0)

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(SierraFont.caption1)
                        .foregroundStyle(SierraTheme.Colors.danger.opacity(0.9))
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
                            .font(SierraFont.subheadline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                SierraTheme.Colors.ember,
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

    // ─────────────────────────────────
    // MARK: - Biometric Button
    // ─────────────────────────────────

    private var biometricButton: some View {
        Button {
            Task { await attemptBiometric() }
        } label: {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.06))
                        .frame(width: 100, height: 100)

                    if isAuthenticating {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(.white)
                    } else {
                        Image(systemName: biometric.biometricIconName)
                            .font(.system(size: 60))
                            .foregroundStyle(SierraTheme.Colors.ember)
                            .symbolEffect(.pulse, isActive: appeared && !showTryAgain)
                    }
                }

                Text("Sign in with \(biometric.biometricDisplayName)")
                    .font(SierraFont.body(16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .buttonStyle(.plain)
        .disabled(isAuthenticating)
    }

    // ─────────────────────────────────
    // MARK: - Password Fallback
    // ─────────────────────────────────

    private var passwordFallbackButton: some View {
        Button {
            // Sign out and route to LoginView
            AuthManager.shared.signOut()
            lifecycle.passwordFallbackUsed()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(SierraFont.caption1)
                Text("Use Password Instead")
                    .font(SierraFont.subheadline)
            }
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                .white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    // ─────────────────────────────────
    // MARK: - Auth Logic
    // ─────────────────────────────────

    @MainActor
    private func attemptBiometric() async {
        guard !isAuthenticating else { return }

        isAuthenticating = true
        errorMessage = nil
        showTryAgain = false

        do {
            try await biometric.authenticate(reason: "Unlock FleetOS")
            // Success — dismiss lock screen
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
