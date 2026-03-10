import SwiftUI

private let navyDark = Color(hex: "0D1B2A")
private let accentOrange = Color(red: 1.0, green: 0.584, blue: 0.0)

struct BiometricLockView: View {
    @State private var appeared = false
    @State private var errorMessage: String?
    @State private var showPasswordFallback = false
    @State private var isAuthenticating = false

    private let biometric = BiometricManager.shared
    private let lifecycle = AppLifecycleMonitor.shared

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "1B3A6B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                Image(systemName: "truck.box.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(accentOrange)
                    .padding(.bottom, 6)

                Text("FleetOS")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.bottom, 30)

                // Welcome message
                if let user = AuthManager.shared.currentUser {
                    Text("Welcome back, \(user.name ?? "User")")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.bottom, 40)
                }

                // Biometric icon button
                biometricButton
                    .scaleEffect(appeared ? 1 : 0.8)
                    .opacity(appeared ? 1 : 0)

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 16)
                        .transition(.opacity)
                }

                Spacer()

                // Password fallback
                if showPasswordFallback {
                    passwordFallbackButton
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .animation(.spring(duration: 0.3), value: showPasswordFallback)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.25)) {
                appeared = true
            }
            // Auto-trigger after 0.5s
            Task {
                try? await Task.sleep(for: .milliseconds(500))
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
                            .font(.system(size: 44))
                            .foregroundStyle(accentOrange)
                            .symbolEffect(.pulse, isActive: appeared)
                    }
                }

                Text("Sign in with \(biometric.biometricDisplayName)")
                    .font(.system(size: 16, weight: .semibold))
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
            lifecycle.passwordFallbackUsed()
            // Sign out to force password re-entry
            AuthManager.shared.needsReauth = true
            AuthManager.shared.isAuthenticated = false
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13))
                Text("Use Password Instead")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

        do {
            try await biometric.authenticate(reason: "Unlock FleetOS")
            // Success — dismiss lock screen
            lifecycle.biometricUnlocked()
        } catch let error as BiometricManager.BiometricError {
            switch error {
            case .userCancelled:
                // Show password fallback
                showPasswordFallback = true
            case .lockedOut:
                errorMessage = error.errorDescription
                showPasswordFallback = true
            default:
                errorMessage = error.errorDescription
                showPasswordFallback = true
            }
        } catch {
            errorMessage = "Authentication failed. Please try again."
            showPasswordFallback = true
        }

        isAuthenticating = false
    }
}

#Preview {
    BiometricLockView()
}
