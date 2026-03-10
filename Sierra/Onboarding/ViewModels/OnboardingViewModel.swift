import SwiftUI

@Observable
final class OnboardingViewModel {

    // MARK: - State

    var currentPage: Int = 0
    var hasCompletedOnboarding: Bool = OnboardingService.hasCompletedOnboarding

    // MARK: - Computed

    let pages = OnboardingPage.pages

    var isLastPage: Bool {
        currentPage == pages.count - 1
    }

    // MARK: - Actions

    func nextPage() {
        guard !isLastPage else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            currentPage += 1
        }
    }

    func skip() {
        completeOnboarding()
    }

    func getStarted() {
        completeOnboarding()
    }

    // MARK: - Private

    private func completeOnboarding() {
        OnboardingService.completeOnboarding()
        withAnimation(.easeInOut(duration: 0.3)) {
            hasCompletedOnboarding = true
        }
    }
}
