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
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 72, height: 72)
                .overlay(
                    Text("FA")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                )

            VStack(spacing: 4) {
                Text("Fleet Admin")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("admin@fleeeos.com")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Fleet Manager")
                    .font(.caption)
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
                        .font(.body)
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
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

#Preview {
    AdminProfileView()
}
