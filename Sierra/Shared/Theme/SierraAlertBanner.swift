import SwiftUI

// MARK: - SierraAlertType

/// Alert banner severity - each carries its message.
enum SierraAlertType: Equatable {
    case success(String)
    case warning(String)
    case error(String)
    case info(String)

    var message: String {
        switch self {
        case .success(let m), .warning(let m), .error(let m), .info(let m): m
        }
    }

    var iconName: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error:   "xmark.circle.fill"
        case .info:    "info.circle.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .success: SierraTheme.Colors.alpineMint
        case .warning: SierraTheme.Colors.warning
        case .error:   SierraTheme.Colors.danger
        case .info:    SierraTheme.Colors.info
        }
    }
}

// MARK: - SierraAlertBanner

/// In-app toast banner - overlaid at the top of a screen.
///
///     .sierraAlert($banner)
struct SierraAlertBanner: View {

    let alertType: SierraAlertType
    var dismissAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // ── Accent icon square ──
            Image(systemName: alertType.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(alertType.accentColor, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))

            // ── Message ──
            Text(alertType.message)
                .font(SierraFont.subheadline)
                .foregroundStyle(SierraTheme.Colors.primaryText)
                .lineLimit(2)

            Spacer()

            // ── Dismiss ──
            if let dismissAction {
                Button(action: dismissAction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(SierraTheme.Colors.granite)
                }
            }
        }
        .padding(Spacing.md)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: Radius.card,
                bottomLeadingRadius: Radius.card,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(alertType.accentColor)
            .frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .sierraShadow(SierraTheme.Shadow.modal)
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - SierraAlertModifier

/// Overlay modifier that drives a banner from an optional `SierraAlertType` binding.
/// Auto-dismisses after 4 seconds.
struct SierraAlertModifier: ViewModifier {

    @Binding var alert: SierraAlertType?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let alert {
                SierraAlertBanner(alertType: alert) {
                    withAnimation(.easeOut(duration: 0.2)) { self.alert = nil }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation(.easeOut(duration: 0.2)) { self.alert = nil }
                    }
                }
                .padding(.top, Spacing.xs)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: alert != nil)
    }
}

// MARK: - View Extension

extension View {
    /// Overlays a Sierra alert banner driven by an optional binding. Auto-dismisses after 4s.
    func sierraAlert(_ alert: Binding<SierraAlertType?>) -> some View {
        modifier(SierraAlertModifier(alert: alert))
    }
}
