import Foundation

struct OnboardingService {
    private static let hasCompletedKey = "hasCompletedOnboarding"

    static var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: hasCompletedKey)
    }

    static func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: hasCompletedKey)
    }

    static func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: hasCompletedKey)
    }
}
