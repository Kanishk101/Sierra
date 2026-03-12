import SwiftUI


/// Shared rejection screen for Driver and Maintenance roles.
/// Shown as .fullScreenCover when user's profile is rejected.
struct RejectedView: View {

    @State private var appeared = false

    private var user: AuthUser? { AuthManager.shared.currentUser }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [SierraTheme.Colors.summitNavy, SierraTheme.Colors.sierraBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Red X icon
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(SierraTheme.Colors.danger)
                    .padding(.bottom, 20)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)

                Text("Application Rejected")
                    .font(SierraFont.title2)
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                Text("Your Fleet Manager has reviewed your\nprofile and it was not approved.")
                    .font(SierraFont.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 24)

                // Rejection reason card
                if let reason = user?.rejectionReason, !reason.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(SierraFont.caption1)
                                .foregroundStyle(SierraTheme.Colors.warning)
                            Text("Reason")
                                .font(SierraFont.caption1)
                                .foregroundStyle(SierraTheme.Colors.warning)
                        }
                        Text(reason)
                            .font(.system(size: 14).italic())
                            .foregroundStyle(.white.opacity(0.8))
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        SierraTheme.Colors.warning.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(SierraTheme.Colors.warning.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
                }

                Spacer()

                // Contact Admin
                if let url = URL(string: "mailto:admin@fleeeos.com") {
                    Link(destination: url) {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .font(SierraFont.subheadline)
                            Text("Contact Admin")
                                .font(SierraFont.body(16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            SierraTheme.Colors.ember,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                    .padding(.horizontal, 28)
                }

                // Sign Out
                Button {
                    AuthManager.shared.signOut()
                } label: {
                    Text("Sign Out")
                        .font(SierraFont.body(16, weight: .semibold))
                        .foregroundStyle(SierraTheme.Colors.danger)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.red.opacity(0.5), lineWidth: 1.5)
                        )
                }
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                appeared = true
            }
        }
    }
}

#Preview {
    RejectedView()
}
