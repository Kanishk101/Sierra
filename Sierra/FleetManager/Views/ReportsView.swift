import SwiftUI

private let navyDark = Color(hex: "0D1B2A")
private let navyMid = Color(hex: "1B3A6B")

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
                            .shadow(color: navyMid.opacity(0.1), radius: 16, y: 6)

                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(navyMid.opacity(0.7))
                    }

                    VStack(spacing: 8) {
                        Text("Reports & Analytics")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(navyDark)

                        Text("Detailed fleet performance reports, fuel analytics, and cost breakdowns are coming in the next update.")
                            .font(.system(size: 15))
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
                .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.05), radius: 16, y: 8)
                .padding(.horizontal, 24)

                Spacer()
            }
            .background(Color(hex: "F2F3F7").ignoresSafeArea())
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func teaserChip(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 13, weight: .medium))
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
