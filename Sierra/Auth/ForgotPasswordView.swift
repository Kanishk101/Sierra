import SwiftUI

/// Forgot password flow (Supabase link-based reset):
/// Step 1 — Enter email → Step 2 — Check your inbox
/// The actual password reset happens via Supabase's email magic-link,
/// not via an in-app OTP code.
struct ForgotPasswordView: View {

    @State private var viewModel = ForgotPasswordViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [SierraTheme.Colors.summitNavy, SierraTheme.Colors.sierraBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Content by step
                Group {
                    switch viewModel.step {
                    case .enterEmail: emailStep
                    case .emailSent:  emailSentStep
                    case .success:    successStep
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: viewModel.step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))

                // Loading overlay
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.step != .success {
                        backButton
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Back Button

    private var backButton: some View {
        Button {
            if viewModel.step == .enterEmail {
                dismiss()
            } else {
                viewModel.goBack()
            }
        } label: {
            Image(systemName: "chevron.left")
                .font(SierraFont.body(16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // ─────────────────────────────────
    // MARK: - Step 1: Enter Email
    // ─────────────────────────────────

    private var emailStep: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 60)

                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(SierraTheme.Colors.ember)
                        .symbolRenderingMode(.hierarchical)

                    VStack(spacing: 8) {
                        Text("Forgot Password?")
                            .font(SierraFont.title2)
                            .foregroundStyle(.white)

                        Text("Enter your email address and we'll send\nyou a password reset link.")
                            .font(SierraFont.subheadline)
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }

                    // Email field
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                                .font(SierraFont.caption1)
                                .foregroundStyle(.white.opacity(0.4))
                                .frame(width: 20)

                            TextField("Email address", text: $viewModel.email)
                                .textFieldStyle(.plain)
                                .font(SierraFont.bodyText)
                                .foregroundStyle(.white)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    viewModel.emailError != nil ? SierraTheme.Colors.danger.opacity(0.7) : .white.opacity(0.1),
                                    lineWidth: 1
                                )
                        )

                        if let error = viewModel.emailError {
                            Text(error)
                                .font(SierraFont.caption2)
                                .foregroundStyle(SierraTheme.Colors.danger.opacity(0.9))
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Send button
                    Button {
                        Task { await viewModel.sendResetCode() }
                    } label: {
                        Text("Send Reset Link")
                            .font(SierraFont.body(17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(SierraTheme.Colors.ember, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, 24)
                    .disabled(viewModel.isLoading)

                    Spacer(minLength: 40)
                }
                .frame(minHeight: geo.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // ─────────────────────────────────
    // MARK: - Step 2: Check Your Inbox
    // ─────────────────────────────────

    private var emailSentStep: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 60)

                    ZStack {
                        Circle()
                            .fill(SierraTheme.Colors.ember.opacity(0.12))
                            .frame(width: 96, height: 96)
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(SierraTheme.Colors.ember)
                    }

                    VStack(spacing: 8) {
                        Text("Check Your Email")
                            .font(SierraFont.title2)
                            .foregroundStyle(.white)

                        Text("We sent a password reset link to\n\(viewModel.maskedEmail)\n\nFollow the link in the email to set a new password.\nThe link expires in 60 minutes.")
                            .font(SierraFont.subheadline)
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, 24)

                    // Resend option
                    VStack(spacing: 12) {
                        Text("Didn't receive the email?")
                            .font(SierraFont.caption1)
                            .foregroundStyle(.white.opacity(0.4))

                        Button {
                            Task { await viewModel.resendResetEmail() }
                        } label: {
                            Text("Resend Link")
                                .font(SierraFont.caption1)
                                .foregroundStyle(SierraTheme.Colors.ember)
                        }
                        .disabled(viewModel.isLoading)
                    }

                    Spacer(minLength: 40)

                    Button {
                        dismiss()
                    } label: {
                        Text("Back to Login")
                            .font(SierraFont.body(17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
                .frame(minHeight: geo.size.height)
            }
        }
    }

    // ─────────────────────────────────
    // MARK: - Success
    // ─────────────────────────────────

    private var successStep: some View {
        VStack(spacing: 24) {
            Spacer()

            AnimatedCheckmarkView(size: 100, color: .green)

            VStack(spacing: 10) {
                Text("Password Reset!")
                    .font(SierraFont.title2)
                    .foregroundStyle(.white)

                Text("Your password has been updated.\nYou can now sign in with your new password.")
                    .font(SierraFont.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Back to Login")
                    .font(SierraFont.body(17, weight: .semibold))
                    .foregroundStyle(SierraTheme.Colors.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.white)
                Text("Sending…")
                    .font(SierraFont.caption1)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .transition(.opacity)
    }
}

#Preview {
    ForgotPasswordView()
}
