import SwiftUI

// MARK: - SierraLoadingView

/// Full-screen loading indicator with optional message.
///
///     SierraLoadingView(message: "Loading vehicles…")
struct SierraLoadingView: View {

    var message: String? = nil

    var body: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(SierraTheme.Colors.ember)
            if let message {
                Text(message)
                    .sierraStyle(.caption)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - SierraSkeletonView

/// Animated shimmer placeholder for loading list rows and cards.
///
///     SierraSkeletonView(height: 16)                // full width text line
///     SierraSkeletonView(width: 120, height: 12)    // short label
struct SierraSkeletonView: View {

    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = Radius.sm

    @State private var phase: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(SierraTheme.Colors.snowfield)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            SierraTheme.Colors.snowfield,
                            SierraTheme.Colors.cloud,
                            SierraTheme.Colors.snowfield
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: phase ? geo.size.width : -geo.size.width)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = true
                }
            }
    }
}
