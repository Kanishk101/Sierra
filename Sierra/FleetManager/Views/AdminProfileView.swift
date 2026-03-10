import SwiftUI

private let navyDark = Color(hex: "0D1B2A")

struct AdminProfileView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Drag indicator
            Capsule()
                .fill(.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            // Avatar
            initialsCircle("FA", size: 72, bg: Color(red: 1.0, green: 0.584, blue: 0.0))

            VStack(spacing: 4) {
                Text("Fleet Admin")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(navyDark)

                Text("admin@fleeeos.com")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)

                Text("Fleet Manager")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1), in: Capsule())
                    .padding(.top, 4)
            }

            Spacer()

            Button {
                AuthManager.shared.signOut()
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16))
                    Text("Log Out")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.red.opacity(0.15), lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Color(hex: "F2F3F7").ignoresSafeArea())
    }
}

#Preview {
    AdminProfileView()
}
