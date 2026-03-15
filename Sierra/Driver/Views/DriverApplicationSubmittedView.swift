import SwiftUI


struct DriverApplicationSubmittedView: View {
    @State private var checkmarkProgress: CGFloat = 0
    @State private var contentAppeared = false
    @State private var isRefreshing = false
    @State private var isRejected = false
    @State private var rejectionReason: String?
    @State private var pollingTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [SierraTheme.Colors.summitNavy, SierraTheme.Colors.sierraBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            mainContent
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
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
        .animation(.spring(duration: 0.4), value: isRejected)
    }

    // MARK: - Polling
    // Polls AuthManager.refreshCurrentUser() every 15 seconds.
    // When the admin approves, is_approved becomes true → ContentView
    // automatically re-routes to the driver dashboard (no manual navigation needed).
    // When rejected, is_approved stays false and rejection_reason is set.

    private func startPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                await pollStatus()
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    @MainActor
    private func pollStatus() async {
        do {
            try await AuthManager.shared.refreshCurrentUser()
        } catch {
            return
        }
        // refreshCurrentUser() updates AuthManager.currentUser in place.
        // If is_approved becomes true, ContentView observes the change and
        // re-routes automatically — no manual navigation needed here.
        //
        // If rejected: show the rejection card in this view.
        if let user = AuthManager.shared.currentUser,
           !user.isApproved,
           let reason = user.rejectionReason, !reason.isEmpty {
            isRejected = true
            rejectionReason = reason
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 40)

                    animatedCheckmark
                        .frame(width: 100, height: 100)

                    VStack(spacing: 10) {
                        Text("Application Submitted!")
                            .font(SierraFont.title2)
                            .foregroundStyle(.white)

                        Text("Your profile has been sent to your Fleet Manager\nfor review. You\u{2019}ll be notified once approved.")
                            .font(SierraFont.subheadline)
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 24)
                    }
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 20)

                    statusCard
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 30)

                    if isRejected, let reason = rejectionReason {
                        rejectedCard(reason: reason)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    refreshButton
                        .opacity(contentAppeared ? 1 : 0)

                    Spacer(minLength: 40)
                }
            }

            signOutButton
                .opacity(contentAppeared ? 1 : 0)
        }
    }

    // MARK: - Animated Checkmark

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

    // MARK: - Status Card

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

    // MARK: - Rejected Card

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

            if let url = URL(string: "mailto:fleet.manager.system.infosys@gmail.com") {
                Link(destination: url) {
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

    // MARK: - Refresh Button

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
                Text(isRefreshing ? "Checking\u{2026}" : "Refresh Status")
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

    // MARK: - Sign Out

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
}

#Preview {
    DriverApplicationSubmittedView()
}
