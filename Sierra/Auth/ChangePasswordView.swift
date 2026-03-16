import SwiftUI

struct ChangePasswordView: View {
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "lock.rotation")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.orange)

                Text("Change Password")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)

                Text("You must change your password on first login.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                VStack(spacing: 16) {
                    SecureField("New Password", text: $newPassword)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding()
                        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color(.separator), lineWidth: 1)
                        )

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding()
                        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color(.separator), lineWidth: 1)
                        )

                    Button {
                        // Password change logic to be implemented with backend
                    } label: {
                        Text("Update Password")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.top, 8)
                }
                .padding(24)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }
}

#Preview {
    ChangePasswordView()
}
