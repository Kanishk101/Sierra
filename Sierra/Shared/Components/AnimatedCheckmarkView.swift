import SwiftUI

/// Reusable animated checkmark shape with circle border.
/// Used by DriverApplicationSubmittedView, MaintenanceApplicationSubmittedView,
/// and ForgotPasswordView success state.
struct AnimatedCheckmarkView: View {

    var size: CGFloat = 100
    var color: Color = .green
    var lineWidth: CGFloat = 4
    var circleLineWidth: CGFloat = 3

    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .strokeBorder(color.opacity(0.2), lineWidth: circleLineWidth)

            // Animated circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: circleLineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Checkmark
            CheckmarkShape()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .padding(size * 0.28)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                progress = 1
            }
        }
    }

    /// Reset and replay the animation.
    func replay() -> AnimatedCheckmarkView {
        var copy = self
        copy._progress = State(initialValue: 0)
        return copy
    }
}

/// Checkmark path shape — three points forming a check.
struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.15, y: h * 0.50))
        path.addLine(to: CGPoint(x: w * 0.40, y: h * 0.75))
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.25))
        return path
    }
}

#Preview {
    ZStack {
        Color(hex: "0D1B2A").ignoresSafeArea()
        AnimatedCheckmarkView(size: 120, color: .green)
    }
}
