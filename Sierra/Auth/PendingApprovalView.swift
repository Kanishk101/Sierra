import SwiftUI

struct PendingApprovalView: View {
    @State private var pulseScale: CGFloat = 0.95
    @State private var pollingTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.08))
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseScale)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                pulseScale = 1.05
                            }
                        }

                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(.orange)
                        .symbolRenderingMode(.hierarchical)
                }

                VStack(spacing: 12) {
                    Text("Pending Approval")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("Your account is under review by the fleet administrator. You\u{2019}ll be notified once approved.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                }

                Spacer()

                Button {
                    AuthManager.shared.signOut()
                } label: {
                    Text("Sign Out")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 48)
            }
        }
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
    }

    // MARK: - Polling

    private func startPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                try? await AuthManager.shared.refreshCurrentUser()
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}

#Preview {
    PendingApprovalView()
}
