import SwiftUI

struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack(alignment: .top) {
            // Apple grouped background - adapts to light/dark automatically
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Skip button ────────────────────────────────────────────
                HStack {
                    Spacer()
                    if !viewModel.isLastPage {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.skip()
                            }
                        } label: {
                            Text("Skip")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .frame(height: 44)
                .animation(.easeInOut(duration: 0.25), value: viewModel.isLastPage)

                // ── Paged slides ───────────────────────────────────────────
                TabView(selection: $viewModel.currentPage) {
                    ForEach(viewModel.pages) { page in
                        OnboardingPageView(page: page)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // ── Bottom chrome ──────────────────────────────────────────
                VStack(spacing: 24) {

                    // Page indicator dots
                    HStack(spacing: 7) {
                        ForEach(viewModel.pages) { page in
                            Capsule()
                                .fill(
                                    page.id == viewModel.currentPage
                                        ? Color.orange
                                        : Color(.systemFill)          // Apple semantic
                                )
                                .frame(
                                    width: page.id == viewModel.currentPage ? 22 : 7,
                                    height: 7
                                )
                                .animation(
                                    .spring(response: 0.3, dampingFraction: 0.7),
                                    value: viewModel.currentPage
                                )
                        }
                    }

                    // CTA button - full-width on last slide, pill trailing on others
                    // Consistent full-width button for all screens
                    // Apple-style: 'Continue' for all but last, 'Get Started' on last
                    Button {
                        if viewModel.isLastPage {
                            viewModel.getStarted()
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.nextPage()
                            }
                        }
                    } label: {
                        HStack {
                            Spacer(minLength: 0)
                            Text(viewModel.isLastPage ? "Get Started" : "Continue")
                                .font(.system(size: 17, weight: .semibold))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 20)
                    .transition(
                        viewModel.isLastPage
                        ? .asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 8)),
                            removal: .opacity
                        )
                        : .opacity
                    )
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isLastPage)
                }
                .padding(.bottom, 52)         // clears home indicator on all iPhones
            }
        }
    }
}

#Preview {
    OnboardingView()
}