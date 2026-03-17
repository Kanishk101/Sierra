import Foundation
import Observation

@Observable
final class OnboardingViewModel {
    var currentPage: Int = 0
    let pages = OnboardingPage.pages

    var isLastPage: Bool {
        currentPage == pages.count - 1
    }

    func nextPage() {
        guard !isLastPage else { return }
        currentPage += 1
    }

    func skip() {
        currentPage = pages.count - 1
    }

    func getStarted() {
        // Transition to main app - e.g., post a notification or update AppState
    }
}