import SwiftUI

struct ChangePasswordView: View {
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [SierraTheme.Colors.summitNavy, SierraTheme.Colors.sierraBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "lock.rotation")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.white.opacity(0.7))

                Text("Change Password")
                    .font(SierraFont.title1)
                    .foregroundStyle(.white)

                Text("You must change your password on first login.")
                    .font(SierraFont.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                VStack(spacing: 16) {
                    SecureField("New Password", text: $newPassword)
                        .textFieldStyle(.plain)
                        .font(SierraFont.bodyText)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                        )

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(.plain)
                        .font(SierraFont.bodyText)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                        )

                    Button {
                        // Password change logic to be implemented with backend
                    } label: {
                        Text("Update Password")
                            .font(SierraFont.body(17, weight: .semibold))
                            .foregroundStyle(SierraTheme.Colors.primaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.top, 8)
                }
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }
}

#Preview {
    ChangePasswordView()
}
