import SwiftUI

struct MaintenanceApplicationSubmittedView: View {
    @State private var checkmarkProgress: CGFloat = 0
    @State private var contentAppeared = false
    @State private var isRefreshing = false
    @State private var isApproved = false
    @State private var isRejected = false
    @State private var rejectionReason: String?
    @State private var pollingTask: Task<Void, Never>?

    var body: some View {
        Group {
            if isApproved {
                MaintenanceTabView()
            } else {
                ZStack {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()

                    mainContent
                }
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
            startPolling()
            Task { await pollStatus() }
        }
        .onDisappear { stopPolling() }
        .animation(.spring(duration: 0.5), value: isApproved)
        .animation(.spring(duration: 0.4), value: isRejected)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 40)

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
                    .frame(width: 100, height: 100)

                    VStack(spacing: 10) {
                        Text("Application Submitted!")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)

                        Text("Your technician profile is under review.\nA fleet administrator will verify your credentials shortly.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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

    // MARK: - Status Card

    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: isRejected ? "xmark.octagon.fill" : "clock.fill")
                .font(SierraFont.scaled(20))
                .foregroundStyle(isRejected ? .red : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Status")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(isRejected ? "Application Rejected" : "Pending Review")
                    .font(SierraFont.scaled(16, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            Text(isRejected ? "Rejected" : "Pending")
                .font(SierraFont.scaled(12, weight: .bold))
                .foregroundStyle(isRejected ? .red : .orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((isRejected ? Color.red : Color.orange).opacity(0.15), in: Capsule())
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 3)
        .padding(.horizontal, 24)
    }

    // MARK: - Rejection

    private func rejectedCard(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                Text("Rejection Reason")
                    .font(SierraFont.scaled(14, weight: .bold))
                    .foregroundStyle(.primary)
            }

            Text(reason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            Button {
                print("\u{1F4DE} Contact Admin tapped")
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "envelope.fill")
                        .font(.caption)
                    Text("Contact Admin")
                        .font(.caption)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.red.opacity(0.7), in: Capsule())
            }
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.red.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    // MARK: - Refresh

    private var refreshButton: some View {
        Button {
            Task { await pollStatus() }
        } label: {
            HStack(spacing: 8) {
                if isRefreshing {
                    ProgressView().scaleEffect(0.8).tint(.orange)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                }
                Text(isRefreshing ? "Checking\u{2026}" : "Refresh Status")
                    .font(.subheadline)
            }
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.15), lineWidth: 1)
            )
        }
        .disabled(isRefreshing)
        .padding(.horizontal, 24)
    }

    private var signOutButton: some View {
        Button {
            AuthManager.shared.signOut(clearBiometricEnrollment: true)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.caption)
                Text("Sign Out")
                    .font(.subheadline)
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Polling

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
        isRefreshing = true
        do {
            try await AuthManager.shared.refreshCurrentUser()
        } catch {
            isRefreshing = false
            return
        }

        if let user = AuthManager.shared.currentUser {
            if user.isApproved && user.isProfileComplete {
                isApproved = true
            } else if !user.isApproved,
                      let reason = user.rejectionReason, !reason.isEmpty {
                isRejected = true
                rejectionReason = reason
            }
        }

        isRefreshing = false
    }
}

#Preview {
    MaintenanceApplicationSubmittedView()
}
