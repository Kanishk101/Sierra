import SwiftUI


struct ReportsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .frame(width: 100, height: 100)
                            .shadow(color: SierraTheme.Colors.sierraBlue.opacity(0.1), radius: 16, y: 6)

                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(SierraTheme.Colors.sierraBlue.opacity(0.7))
                    }

                    VStack(spacing: 8) {
                        Text("Reports & Analytics")
                            .font(SierraFont.title2)
                            .foregroundStyle(SierraTheme.Colors.primaryText)

                        Text("Detailed fleet performance reports, fuel analytics, and cost breakdowns are coming in the next update.")
                            .font(SierraFont.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 40)
                    }

                    // Teaser cards
                    HStack(spacing: 12) {
                        teaserChip(icon: "fuelpump.fill", label: "Fuel", color: .green)
                        teaserChip(icon: "dollarsign.circle.fill", label: "Costs", color: SierraTheme.Colors.warning)
                        teaserChip(icon: "chart.line.uptrend.xyaxis", label: "Trends", color: .blue)
                    }
                }
                .padding(32)
                .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.05), radius: 16, y: 8)
                .padding(.horizontal, 24)

                Spacer()
            }
            .background(SierraTheme.Colors.appBackground.ignoresSafeArea())
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func teaserChip(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(SierraFont.caption1)
                .foregroundStyle(color)
            Text(label)
                .font(SierraFont.caption1)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(color.opacity(0.08), in: Capsule())
    }
}

#Preview {
    ReportsView()
}
