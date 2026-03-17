import Foundation

/// Drives which SF Symbol animation plays when the slide appears.


struct OnboardingPage: Identifiable {
    let id: Int
    let icon: String
    // iconAnimation removed; always static
    let title: String
    let subtitle: String

    static let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            icon: "sierra",
            title: "Welcome to Sierra",
            subtitle: "The complete fleet management platform built for managers, drivers, and maintenance teams."
        ),
        OnboardingPage(
            id: 1,
            icon: "scope",
            title: "Live Fleet Tracking",
            subtitle: "See every vehicle on the map in real time. Know exactly where your fleet is, always."
        ),
        OnboardingPage(
            id: 2,
            icon: "gearshape.2.fill",
            title: "Proactive Maintenance",
            subtitle: "Schedule services, log repairs, and get alerts before issues become costly problems."
        ),
        OnboardingPage(
            id: 3,
            icon: "dollarsign.arrow.circlepath",
            title: "Cut Operational Costs",
            subtitle: "Track fuel usage, delivery expenses, and generate reports that drive smarter decisions."
        ),
        OnboardingPage(
            id: 4,
            icon: "person.3.sequence.fill",
            title: "Three Roles.\nOne Platform.",
            subtitle: "Managers, Drivers, and Maintenance - each with a tailored experience built for their work."
        )
    ]
}