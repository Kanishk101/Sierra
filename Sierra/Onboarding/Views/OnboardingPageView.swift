import SwiftUI

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Frosted glass card with SF Symbol icon
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.orange.opacity(0.08))
                    .frame(width: 180, height: 180)
                    .shadow(color: Color.orange.opacity(0.08), radius: 24, y: 8)

                Image(systemName: page.icon)
                    .font(.system(size: 80, weight: .light))
                    .foregroundStyle(.orange)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .kerning(-0.4)

                Text(page.subtitle)
                    .font(.system(size: 17, weight: .regular, design: .default))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    OnboardingPageView(page: OnboardingPage.pages[0])
        .background(Color(.systemGroupedBackground))
}
