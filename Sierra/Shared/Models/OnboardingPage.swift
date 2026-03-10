import Foundation

struct OnboardingPage: Identifiable, Equatable {
    let id: Int
    let icon: String
    let title: String
    let subtitle: String

    static let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            icon: "truck.box.fill",
            title: "Welcome to FleetOS",
            subtitle: "Your complete fleet management solution — built for managers, drivers, and maintenance teams."
        ),
        OnboardingPage(
            id: 1,
            icon: "map.fill",
            title: "Real-Time Tracking",
            subtitle: "Monitor your entire fleet live on the map. Know where every vehicle is, instantly."
        ),
        OnboardingPage(
            id: 2,
            icon: "wrench.and.screwdriver.fill",
            title: "Stay Ahead of Repairs",
            subtitle: "Schedule maintenance, log repairs, and keep your vehicles in peak condition."
        ),
        OnboardingPage(
            id: 3,
            icon: "fuelpump.fill",
            title: "Control Operational Costs",
            subtitle: "Track fuel logs, delivery costs, and generate detailed performance reports."
        ),
        OnboardingPage(
            id: 4,
            icon: "person.3.fill",
            title: "Three Roles. One Platform.",
            subtitle: "Fleet Managers, Drivers, and Maintenance Personnel — each with a tailored experience."
        )
    ]
}
