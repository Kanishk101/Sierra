import SwiftUI

struct PendingApprovalView: View {
    @State private var pulseScale: CGFloat = 0.95
    @State private var pollingTask: Task<Void, Never>?
    @State private var approvedRole: UserRole?

    var body: some View {
        Group {
            if approvedRole == .driver {
                DriverTabView()
            } else if approvedRole == .maintenancePersonnel {
                MaintenanceTabView()
            } else {
                ZStack {
                    SierraTheme.Colors.appBackground
                        .ignoresSafeArea()

                    VStack(spacing: 32) {
                        Spacer()

                        ZStack {
                            Circle()
                                .fill(SierraTheme.Colors.ember.opacity(0.08))
                                .frame(width: 140, height: 140)
                                .scaleEffect(pulseScale)
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                                        pulseScale = 1.12
                                    }
                                }

                            Image(systemName: "clock.badge.checkmark.fill")
                                .font(SierraFont.scaled(60, weight: .light))
                                .foregroundStyle(SierraTheme.Colors.ember)
                                .symbolRenderingMode(.hierarchical)
                        }

                        VStack(spacing: 16) {
                            Text("Pending Approval")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(SierraTheme.Colors.primaryText)

                            Text("Your account is under review by the fleet administrator. You\u{2019}ll be notified once approved.")
                                .font(SierraFont.subheadline)
                                .foregroundStyle(SierraTheme.Colors.secondaryText)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, 40)
                        }

                        Spacer()

                        Button {
                            AuthManager.shared.signOut()
                        } label: {
                            Text("Sign Out")
                                .font(SierraFont.body(16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color(red: 0.85, green: 0.15, blue: 0.15), in: Capsule())
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 48)
                    }
                }
            }
        }
        .onAppear {
            startPolling()
            Task { await pollOnce() }
        }
        .onDisappear { stopPolling() }
    }

    // MARK: - Polling

    private func startPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                await pollOnce()
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    @MainActor
    private func pollOnce() async {
        try? await AuthManager.shared.refreshCurrentUser()
        guard let user = AuthManager.shared.currentUser else { return }
        if user.isApproved && user.isProfileComplete {
            approvedRole = user.role
        }
    }
}

#Preview {
    PendingApprovalView()
}
