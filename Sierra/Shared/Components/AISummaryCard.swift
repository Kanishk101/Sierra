import SwiftUI

// MARK: - AISummaryCard
//
// Reusable card that shows a Groq-generated AI summary in three states:
//   .idle / .loading → shimmer placeholder
//   .loaded(text)    → sparkles icon + summary text
//   .failed(msg)     → warning icon + retry button

struct AISummaryCard: View {

    enum SummaryState {
        case idle
        case loading
        case loaded(String)
        case failed(String)
    }

    let state: SummaryState
    var isFlat: Bool = false
    let onRefresh: () -> Void

    // Shimmer animation
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(SierraFont.caption1.weight(.semibold))
                    .foregroundStyle(Color.appOrange)
                Text("AI INSIGHT")
                    .font(SierraFont.caption2.weight(.bold))
                    .foregroundStyle(Color.appOrange)
                    .kerning(0.8)
                Spacer()
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(SierraFont.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .disabled(isLoading)
                .accessibilityLabel("Refresh AI summary")
            }
            .padding(.horizontal, isFlat ? 0 : 14)
            .padding(.top, isFlat ? 0 : 12)
            .padding(.bottom, 8)

            Divider().padding(.horizontal, isFlat ? 0 : 14)

            // Body
            Group {
                switch state {
                case .idle, .loading:
                    loadingBody
                        .padding(.horizontal, isFlat ? 0 : 14)

                case .loaded(let text):
                    Text(text)
                        .font(SierraFont.body(14))
                        .foregroundStyle(.primary)
                        .lineSpacing(3)
                        .padding(.horizontal, isFlat ? 0 : 14)
                        .padding(.vertical, 12)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))

                case .failed(let msg):
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(Color.appOrange)
                        Text(msg)
                            .font(SierraFont.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Spacer()
                        Button("Retry") { onRefresh() }
                            .font(SierraFont.footnote.weight(.semibold))
                            .foregroundStyle(Color.appOrange)
                            .accessibilityLabel("Retry AI summary")
                    }
                    .padding(.horizontal, isFlat ? 0 : 14)
                    .padding(.vertical, 12)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isLoaded)
        }
        .background(
            Group {
                if !isFlat {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
                }
            }
        )
        .overlay(
            Group {
                if !isFlat {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.appOrange.opacity(0.18), lineWidth: 1)
                }
            }
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Loading shimmer

    private var loadingBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            shimmerLine(width: .infinity)
            shimmerLine(width: 200)
            shimmerLine(width: 240)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(Color.appOrange)
                Text("Generating AI summary…")
                    .font(SierraFont.caption1)
                    .foregroundStyle(.secondary)
            },
            alignment: .center
        )
    }

    private func shimmerLine(width: CGFloat) -> some View {
        let isInfinity = width == .infinity
        return GeometryReader { geo in
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemFill))
                .frame(width: isInfinity ? geo.size.width : width, height: 10)
                .overlay(
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.4), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .offset(x: shimmerOffset)
                    .clipped()
                )
        }
        .frame(height: 10)
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                shimmerOffset = 300
            }
        }
    }

    // MARK: - Helpers

    private var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    private var isLoaded: Bool {
        if case .loaded = state { return true }
        return false
    }
}

#Preview {
    VStack(spacing: 16) {
        AISummaryCard(state: .loading, onRefresh: {})
        AISummaryCard(state: .loaded("Fleet utilisation is healthy at 73%. The top performer is Tata Ace Gold with 18 trips. Fuel spend is within budget. Consider scheduling Tata Signa 4825 for preventive maintenance soon."), onRefresh: {})
        AISummaryCard(state: .failed("Groq API error (401). Check your API key."), onRefresh: {})
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
