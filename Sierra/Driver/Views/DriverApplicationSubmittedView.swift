import SwiftUI


struct DriverApplicationSubmittedView: View {
    @State private var checkmarkProgress: CGFloat = 0
    @State private var contentAppeared = false
    @State private var isRefreshing = false
    @State private var isApproved = false
    @State private var isRejected = false
    @State private var rejectionReason: String?

    // Simulate polling
    private let store = StaffApplicationStore.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [SierraTheme.Colors.summitNavy, SierraTheme.Colors.sierraBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if isApproved {
                approvedOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                mainContent
            }
        }
        .interactiveDismissDisabled()
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                checkmarkProgress = 1
            }
            withAnimation(.spring(duration: 0.6, bounce: 0.2).delay(0.8)) {
                contentAppeared = true
            }
        }
        .animation(.spring(duration: 0.5), value: isApproved)
        .animation(.spring(duration: 0.4), value: isRejected)
    }

    // ─────────────────────────────────
    // MARK: - Main Content
    // ─────────────────────────────────

    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 40)

                    // Animated checkmark
                    animatedCheckmark
                        .frame(width: 100, height: 100)

                    // Title
                    VStack(spacing: 10) {
                        Text("Application Submitted!")
                            .font(SierraFont.title2)
                            .foregroundStyle(.white)

                        Text("Your profile has been sent to your Fleet Manager\nfor review. You'll be notified once approved.")
                            .font(SierraFont.subheadline)
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 24)
                    }
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 20)

                    // Status card
                    statusCard
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 30)

                    // Rejected card (if applicable)
                    if isRejected, let reason = rejectionReason {
                        rejectedCard(reason: reason)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Refresh button
                    refreshButton
                        .opacity(contentAppeared ? 1 : 0)

                    Spacer(minLength: 40)
                }
            }

            // Sign out
            signOutButton
                .opacity(contentAppeared ? 1 : 0)
        }
    }

    // ─────────────────────────────────
    // MARK: - Animated Checkmark
    // ─────────────────────────────────

    private var animatedCheckmark: some View {
        ZStack {
            Circle()
                .strokeBorder(.green.opacity(0.2), lineWidth: 3)

            Circle()
                .trim(from: 0, to: checkmarkProgress)
                .stroke(.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            CheckmarkShape()
                .trim(from: 0, to: checkmarkProgress)
                .stroke(.green, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .padding(28)
        }
    }

    // ─────────────────────────────────
    // MARK: - Status Card
    // ─────────────────────────────────

    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: isRejected ? "xmark.octagon.fill" : "clock.fill")
                .font(.system(size: 20))
                .foregroundStyle(isRejected ? .red : SierraTheme.Colors.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text("Status")
                    .font(SierraFont.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                Text(isRejected ? "Application Rejected" : "Pending Review")
                    .font(SierraFont.body(16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer()

            // Amber/red badge
            Text(isRejected ? "Rejected" : "Pending")
                .font(SierraFont.body(12, weight: .bold))
                .foregroundStyle(isRejected ? .red : SierraTheme.Colors.warning)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((isRejected ? Color.red : SierraTheme.Colors.warning).opacity(0.15), in: Capsule())
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    // ─────────────────────────────────
    // MARK: - Rejected Card
    // ─────────────────────────────────

    private func rejectedCard(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.danger)
                Text("Rejection Reason")
                    .font(SierraFont.body(14, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(reason)
                .font(SierraFont.caption1)
                .foregroundStyle(.white.opacity(0.7))
                .lineSpacing(3)

            Button {
                // Simulated contact action
                print("📞 Contact Admin tapped")
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "envelope.fill")
                        .font(SierraFont.caption1)
                    Text("Contact Admin")
                        .font(SierraFont.caption1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(SierraTheme.Colors.danger.opacity(0.7), in: Capsule())
            }
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.red.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    // ─────────────────────────────────
    // MARK: - Refresh Button
    // ─────────────────────────────────

    private var refreshButton: some View {
        Button {
            Task { await pollStatus() }
        } label: {
            HStack(spacing: 8) {
                if isRefreshing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(SierraFont.subheadline)
                }
                Text(isRefreshing ? "Checking…" : "Refresh Status")
                    .font(SierraFont.subheadline)
            }
            .foregroundStyle(.white.opacity(0.7))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            )
        }
        .disabled(isRefreshing)
        .padding(.horizontal, 24)
    }

    // ─────────────────────────────────
    // MARK: - Sign Out
    // ─────────────────────────────────

    private var signOutButton: some View {
        Button {
            AuthManager.shared.signOut()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(SierraFont.caption1)
                Text("Sign Out")
                    .font(SierraFont.subheadline)
            }
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    // ─────────────────────────────────
    // MARK: - Approved Overlay
    // ─────────────────────────────────

    private var approvedOverlay: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.green.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(SierraTheme.Colors.alpineMint)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 10) {
                Text("You're Approved!")
                    .font(SierraFont.title1)
                    .foregroundStyle(.white)

                Text("Welcome to FleetOS. You can now access all driver features.")
                    .font(SierraFont.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            Button {
                // Navigate to DriverDashboard
                if var user = AuthManager.shared.currentUser {
                    user.isApproved = true
                    AuthManager.shared.currentUser = user
                    _ = KeychainService.save(user, forKey: "com.fleetOS.currentUser")
                    AuthManager.shared.isAuthenticated = true
                }
            } label: {
                Text("Get Started")
                    .font(SierraFont.body(17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // ─────────────────────────────────
    // MARK: - Poll
    // ─────────────────────────────────

    @MainActor
    private func pollStatus() async {
        isRefreshing = true
        try? await Task.sleep(for: .milliseconds(1200))

        // Check the store for this user's application status
        if let email = AuthManager.shared.currentUser?.email,
           let app = store.applications.first(where: { $0.email == email || $0.status != .pending }) {
            switch app.status {
            case .approved:
                isApproved = true
            case .rejected:
                isRejected = true
                rejectionReason = app.rejectionReason ?? "No reason provided."
            case .pending:
                break
            }
        }

        isRefreshing = false
    }
}

#Preview {
    DriverApplicationSubmittedView()
}
