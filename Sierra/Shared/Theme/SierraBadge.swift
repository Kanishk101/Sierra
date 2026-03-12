import SwiftUI

// MARK: - SierraBadge Size

/// Controls font, padding, and overall density of a SierraBadge.
enum SierraBadgeSize {
    /// 11pt caption2, compact padding (3v × 8h)
    case compact
    /// 12pt caption1, standard padding (5v × 12h) — **default**
    case regular
    /// 13pt footnote, spacious padding (6v × 14h)
    case large

    var font: Font {
        switch self {
        case .compact: SierraFont.caption2
        case .regular: SierraFont.caption1
        case .large:   SierraFont.footnote
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .compact: 3
        case .regular: 5
        case .large:   6
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .compact: 8
        case .regular: 12
        case .large:   14
        }
    }

    var dotSize: CGFloat {
        switch self {
        case .compact: 4
        case .regular: 5
        case .large:   6
        }
    }
}

// MARK: - SierraBadge

/// Universal status badge. The **only** badge component in the project.
///
///     SierraBadge(vehicle.status)
///     SierraBadge(DriverStatus.available, size: .compact)
///     SierraBadge(label: "Custom", dotColor: .blue, backgroundColor: .blue.opacity(0.12), foregroundColor: .blue)
struct SierraBadge: View {

    private let label: String
    private let dotColor: Color
    private let bgColor: Color
    private let fgColor: Color
    private let size: SierraBadgeSize
    private let showDot: Bool
    private let iconName: String?

    // MARK: - Primary Initializer

    /// Renders a badge from any `SierraStatus` conforming enum.
    init<S: SierraStatus>(_ status: S, size: SierraBadgeSize = .regular) {
        self.label = status.label
        self.dotColor = status.dotColor
        self.bgColor = status.backgroundColor
        self.fgColor = status.foregroundColor
        self.size = size
        self.showDot = status.showsDot
        self.iconName = status.icon
    }

    // MARK: - Custom Initializer

    /// One-off badge with explicit colors. Prefer the protocol-based init.
    init(
        label: String,
        dotColor: Color,
        backgroundColor: Color,
        foregroundColor: Color,
        size: SierraBadgeSize = .regular,
        showDot: Bool = true,
        icon: String? = nil
    ) {
        self.label = label
        self.dotColor = dotColor
        self.bgColor = backgroundColor
        self.fgColor = foregroundColor
        self.size = size
        self.showDot = showDot
        self.iconName = icon
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 5) {
            if showDot {
                Circle()
                    .fill(dotColor)
                    .frame(width: size.dotSize, height: size.dotSize)
            }

            if let iconName {
                Image(systemName: iconName)
                    .font(.system(size: size == .compact ? 9 : 10))
            }

            Text(label)
                .font(size.font)
                .fontWeight(.semibold)
                .tracking(0.3)
                .fixedSize()
        }
        .foregroundStyle(fgColor)
        .padding(.vertical, size.verticalPadding)
        .padding(.horizontal, size.horizontalPadding)
        .background(bgColor, in: Capsule())
    }
}

// MARK: - Preview

#Preview("Badge Gallery") {
    VStack(spacing: 12) {
        Text("Vehicle").sierraStyle(.eyebrow)
        HStack { ForEach(VehicleStatus.allCases, id: \.self) { SierraBadge($0) } }

        Text("Driver").sierraStyle(.eyebrow)
        HStack { ForEach(DriverStatus.allCases, id: \.self) { SierraBadge($0, size: .compact) } }

        Text("Maintenance").sierraStyle(.eyebrow)
        HStack { ForEach(MaintenanceStatus.allCases, id: \.self) { SierraBadge($0) } }

        Text("Document").sierraStyle(.eyebrow)
        HStack { ForEach(DocumentStatus.allCases, id: \.self) { SierraBadge($0, size: .large) } }
    }
    .padding()
}
