import SwiftUI


struct ReportsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.blue.opacity(0.06))
                            .frame(width: 100, height: 100)
                            .shadow(color: Color.blue.opacity(0.08), radius: 16, y: 6)

                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(.blue)
                    }

                    VStack(spacing: 8) {
                        Text("Reports & Analytics")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)

                        Text("Detailed fleet performance reports, fuel analytics, and cost breakdowns are coming in the next update.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 40)
                    }

                    // Teaser cards
                    HStack(spacing: 12) {
                        teaserChip(icon: "fuelpump.fill", label: "Fuel", color: .green)
                        teaserChip(icon: "dollarsign.circle.fill", label: "Costs", color: .orange)
                        teaserChip(icon: "chart.line.uptrend.xyaxis", label: "Trends", color: .blue)
                    }
                }
                .padding(32)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.05), radius: 16, y: 8)
                .padding(.horizontal, 24)

                Spacer()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func teaserChip(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
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
