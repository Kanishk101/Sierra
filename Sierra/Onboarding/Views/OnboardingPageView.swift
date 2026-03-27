import SwiftUI

struct OnboardingPageView: View {
    let page: OnboardingPage

    // Trigger token - flipped to true on appear to fire one-shot animations.
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Icon card ──
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.orange.opacity(0.10))
                    .frame(width: 160, height: 160)

                // Make all icons the same size and alignment
                if page.id == 0 {
                    Image(page.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .padding(12)
                } else {
                    Image(systemName: page.icon)
                        .font(SierraFont.scaled(72, weight: .regular))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.orange)
                }
            }
            .padding(.bottom, 40)

            // ── Text ──
            VStack(spacing: 12) {
                Text(page.title)
                    .font(SierraFont.scaled(34, weight: .bold))
                    .foregroundStyle(Color(.label))
                    .multilineTextAlignment(.center)
                    .tracking(-0.5)
                    .minimumScaleFactor(0.75)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)

                Text(page.subtitle)
                    .font(SierraFont.scaled(17, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                appeared = true
            }
        }
        .onDisappear {
            appeared = false
        }
    }

    // iconView and iconAnimation removed; all icons are static
}

#Preview {
    OnboardingPageView(page: OnboardingPage.pages[1])
        .background(Color(.systemGroupedBackground))
}