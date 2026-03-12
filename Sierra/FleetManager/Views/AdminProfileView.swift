import SwiftUI


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
            initialsCircle("FA", size: 72, bg: SierraTheme.Colors.ember)

            VStack(spacing: 4) {
                Text("Fleet Admin")
                    .font(SierraFont.title3)
                    .foregroundStyle(SierraTheme.Colors.primaryText)

                Text("admin@fleeeos.com")
                    .font(SierraFont.subheadline)
                    .foregroundStyle(.secondary)

                Text("Fleet Manager")
                    .font(SierraFont.caption1)
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
                        .font(SierraFont.bodyText)
                    Text("Log Out")
                        .font(SierraFont.body(17, weight: .semibold))
                }
                .foregroundStyle(SierraTheme.Colors.danger)
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
        .background(SierraTheme.Colors.appBackground.ignoresSafeArea())
    }
}

#Preview {
    AdminProfileView()
}
