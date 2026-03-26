import SwiftUI

enum DriverTripCardActionStyle {
    case outlineOrange
    case solidDark
    case solidNavigate
    case success
    case cancelled
    case neutral
}

struct DriverTripCardActionButton: View {
    let title: String
    let icon: String
    let style: DriverTripCardActionStyle
    var action: (() -> Void)? = nil
    var isDisabled: Bool = false

    var body: some View {
        Group {
            if let action {
                Button(action: action) { label }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
            } else {
                label
            }
        }
    }

    private var label: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .foregroundColor(foregroundColor)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Capsule().fill(backgroundColor))
        .overlay {
            if let borderColor {
                Capsule().stroke(borderColor, lineWidth: 1.5)
            }
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .outlineOrange: return .appOrange
        case .solidDark: return .white
        case .solidNavigate: return .white
        case .success: return Color(red: 0.20, green: 0.65, blue: 0.32)
        case .cancelled: return Color(red: 0.90, green: 0.22, blue: 0.18)
        case .neutral: return .appTextSecondary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .outlineOrange: return .appOrange.opacity(0.08)
        case .solidDark: return .appTextPrimary
        case .solidNavigate: return Color(red: 0.20, green: 0.65, blue: 0.32)
        case .success: return Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.12)
        case .cancelled: return .appDivider.opacity(0.3)
        case .neutral: return Color(.tertiarySystemGroupedBackground)
        }
    }

    private var borderColor: Color? {
        switch style {
        case .outlineOrange: return .appOrange.opacity(0.25)
        case .success: return Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.3)
        case .neutral: return .appDivider.opacity(0.6)
        default: return nil
        }
    }
}
