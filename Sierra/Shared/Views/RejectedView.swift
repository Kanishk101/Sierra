import SwiftUI

/// Shared rejection screen for Driver and Maintenance roles.
/// Shown as .fullScreenCover when user's profile is rejected.
struct RejectedView: View {
    @Environment(\.openURL) private var openURL
    @State private var appeared = false
    private var user: AuthUser? { AuthManager.shared.currentUser }

    var body: some View {
        ZStack {
            SierraTheme.Colors.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Red X icon
                ZStack {
                    Circle()
                        .fill(SierraTheme.Colors.danger.opacity(0.12))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 54, weight: .light))
                        .foregroundStyle(SierraTheme.Colors.danger)
                        .symbolRenderingMode(.hierarchical)
                }
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, 24)
                .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text("Application Not Approved")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(SierraTheme.Colors.primaryText)

                    Text("Your profile has been reviewed by the fleet administrator and unfortunately it was not approved at this time.")
                        .font(SierraFont.subheadline)
                        .foregroundStyle(SierraTheme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 32)

                // Rejection reason card
                if let reason = user?.rejectionReason, !reason.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.bubble.fill")
                                .font(.caption)
                                .foregroundStyle(SierraTheme.Colors.ember)
                            Text("ADMINISTRATOR FEEDBACK")
                                .font(SierraFont.caption2.weight(.bold))
                                .foregroundStyle(SierraTheme.Colors.ember)
                                .tracking(0.5)
                        }
                        
                        Text(reason)
                            .font(SierraFont.body(15, weight: .medium).italic())
                            .foregroundStyle(SierraTheme.Colors.primaryText)
                            .lineSpacing(4)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        SierraTheme.Colors.ember.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .strokeBorder(SierraTheme.Colors.ember.opacity(0.15), lineWidth: 1)
                    )
                    .sierraShadow(SierraShadow(color: SierraTheme.Colors.ember.opacity(0.05), radius: 8, x: 0, y: 4))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Rejection reason: \(reason)")
                }

                Spacer()

                VStack(spacing: 16) {
                    // Contact Admin
                    SierraButton.primary("Contact Support", icon: "envelope.fill") {
                        if let url = URL(string: "mailto:support@sierra.com") {
                            openURL(url)
                        }
                    }
                    // Sign Out
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
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) {
                appeared = true
            }
        }
    }
}

#Preview {
    RejectedView()
}
