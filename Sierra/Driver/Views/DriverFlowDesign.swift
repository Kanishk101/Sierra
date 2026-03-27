import SwiftUI

enum DriverFlowTypography {
    static let screenTitle = Font.system(size: 30, weight: .bold, design: .rounded)
    static let sectionTitle = Font.system(size: 22, weight: .bold, design: .rounded)
    static let cardTitle = Font.system(size: 17, weight: .bold, design: .rounded)
    static let body = Font.system(size: 15, weight: .medium, design: .rounded)
    static let bodyStrong = Font.system(size: 15, weight: .bold, design: .rounded)
    static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
    static let captionStrong = Font.system(size: 12, weight: .bold, design: .rounded)
    static let mono = Font.system(size: 12, weight: .bold, design: .monospaced)
}

enum DriverFlowSpacing {
    static let screenHorizontal: CGFloat = 20
    static let section: CGFloat = 16
    static let cardGap: CGFloat = 14
    static let cardPadding: CGFloat = 18
    static let chipHorizontal: CGFloat = 10
    static let chipVertical: CGFloat = 6
}

extension View {
    func driverFlowCardStyle(cornerRadius: CGFloat = 22) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.appCardBg)
                    .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.appDivider.opacity(0.35), lineWidth: 1)
            )
    }
}

