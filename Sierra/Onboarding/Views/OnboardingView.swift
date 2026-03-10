import SwiftUI

struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            // Full-bleed gradient background
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "1B3A6B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar — Skip button
                HStack {
                    Spacer()
                    if !viewModel.isLastPage {
                        Button {
                            viewModel.skip()
                        } label: {
                            Text("Skip")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .frame(height: 44)

                // Paged content
                TabView(selection: $viewModel.currentPage) {
                    ForEach(viewModel.pages) { page in
                        OnboardingPageView(page: page)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: viewModel.currentPage)

                // Bottom area — page dots + button
                VStack(spacing: 28) {
                    // Custom page indicator
                    HStack(spacing: 8) {
                        ForEach(viewModel.pages) { page in
                            Capsule()
                                .fill(.white.opacity(page.id == viewModel.currentPage ? 1.0 : 0.3))
                                .frame(
                                    width: page.id == viewModel.currentPage ? 24 : 8,
                                    height: 8
                                )
                                .animation(.easeInOut(duration: 0.3), value: viewModel.currentPage)
                        }
                    }

                    // Action button
                    if viewModel.isLastPage {
                        Button {
                            viewModel.getStarted()
                        } label: {
                            Text("Get Started")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color(hex: "0D1B2A"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .padding(.horizontal, 24)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        HStack {
                            Spacer()
                            Button {
                                viewModel.nextPage()
                            } label: {
                                HStack(spacing: 6) {
                                    Text("Next")
                                        .font(.system(size: 17, weight: .semibold))
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 28)
                                .frame(height: 50)
                                .background(.white.opacity(0.15), in: Capsule())
                                .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                            }
                        }
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                    }
                }
                .padding(.bottom, 48)
                .animation(.easeInOut(duration: 0.35), value: viewModel.isLastPage)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
