import SwiftUI

struct PendingApprovalView: View {
    @State private var pulseScale: CGFloat = 0.95

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [SierraTheme.Colors.summitNavy, SierraTheme.Colors.sierraBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseScale)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                pulseScale = 1.05
                            }
                        }

                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(.white.opacity(0.8))
                        .symbolRenderingMode(.hierarchical)
                }

                VStack(spacing: 12) {
                    Text("Pending Approval")
                        .font(SierraFont.title1)
                        .foregroundStyle(.white)

                    Text("Your account is under review by the fleet administrator. You'll be notified once approved.")
                        .font(SierraFont.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                }

                Spacer()

                Button {
                    AuthManager.shared.signOut()
                } label: {
                    Text("Sign Out")
                        .font(SierraFont.body(17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 48)
            }
        }
    }
}

#Preview {
    PendingApprovalView()
}
