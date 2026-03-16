import SwiftUI


/// Shared rejection screen for Driver and Maintenance roles.
/// Shown as .fullScreenCover when user's profile is rejected.
struct RejectedView: View {

    @State private var appeared = false

    private var user: AuthUser? { AuthManager.shared.currentUser }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Red X icon
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)
                    .padding(.bottom, 20)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)

                Text("Application Rejected")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.bottom, 8)

                Text("Your Fleet Manager has reviewed your\nprofile and it was not approved.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 24)

                // Rejection reason card
                if let reason = user?.rejectionReason, !reason.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("Reason")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        Text(reason)
                            .font(.system(size: 14).italic())
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color.orange.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
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
                                .font(.subheadline)
                            Text("Contact Admin")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            Color.orange,
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.red)
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
