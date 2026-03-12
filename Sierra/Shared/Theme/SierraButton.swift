import SwiftUI

// MARK: - SierraButton

/// Convenience wrapper that pairs a `Button` with the correct `SierraButtonStyle`.
///
///     SierraButton.primary("Create Trip") { … }
///     SierraButton.danger("Remove Driver") { … }
///     SierraButton.ghost("Add Vehicle", icon: "plus") { … }
struct SierraButton: View {

    // MARK: - Variant

    enum Variant {
        case primary, secondary, ghost, outline, danger, text
    }

    // MARK: - Properties

    let title: String
    let variant: Variant
    var icon: String? = nil
    var isFullWidth: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    // MARK: - Body

    var body: some View {
        switch variant {
        case .primary:
            Button(action: action) { label }.buttonStyle(SierraPrimaryButtonStyle()).disabled(isLoading)
        case .secondary:
            Button(action: action) { label }.buttonStyle(SierraSecondaryButtonStyle()).disabled(isLoading)
        case .ghost:
            Button(action: action) { label }.buttonStyle(SierraGhostButtonStyle()).disabled(isLoading)
        case .outline:
            Button(action: action) { label }.buttonStyle(SierraOutlineButtonStyle()).disabled(isLoading)
        case .danger:
            Button(action: action) { label }.buttonStyle(SierraDangerButtonStyle()).disabled(isLoading)
        case .text:
            Button(action: action) { label }.buttonStyle(SierraTextButtonStyle()).disabled(isLoading)
        }
    }

    // MARK: - Label

    @ViewBuilder
    private var label: some View {
        if isLoading {
            ProgressView()
                .tint(loadingTint)
                .frame(width: 20, height: 20)
        } else {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
            }
        }
    }


    private var loadingTint: Color {
        switch variant {
        case .primary, .secondary: .white
        case .ghost, .text:        SierraTheme.Colors.ember
        case .outline:             SierraTheme.Colors.summitNavy
        case .danger:              SierraTheme.Colors.danger
        }
    }

    // MARK: - Convenience Factories

    static func primary(_ title: String, icon: String? = nil, isLoading: Bool = false, action: @escaping () -> Void) -> SierraButton {
        SierraButton(title: title, variant: .primary, icon: icon, isFullWidth: true, isLoading: isLoading, action: action)
    }

    static func secondary(_ title: String, icon: String? = nil, isLoading: Bool = false, action: @escaping () -> Void) -> SierraButton {
        SierraButton(title: title, variant: .secondary, icon: icon, isFullWidth: true, isLoading: isLoading, action: action)
    }

    static func ghost(_ title: String, icon: String? = nil, action: @escaping () -> Void) -> SierraButton {
        SierraButton(title: title, variant: .ghost, icon: icon, isFullWidth: false, action: action)
    }

    static func outline(_ title: String, icon: String? = nil, action: @escaping () -> Void) -> SierraButton {
        SierraButton(title: title, variant: .outline, icon: icon, isFullWidth: false, action: action)
    }

    static func danger(_ title: String, icon: String? = nil, action: @escaping () -> Void) -> SierraButton {
        SierraButton(title: title, variant: .danger, icon: icon, isFullWidth: false, action: action)
    }

    static func text(_ title: String, action: @escaping () -> Void) -> SierraButton {
        SierraButton(title: title, variant: .text, isFullWidth: false, action: action)
    }
}

// MARK: - SierraIconButton

/// Compact icon button for navigation bars, toolbars, and inline actions.
///
///     SierraIconButton("bell.fill") { … }
///     SierraIconButton("plus", tint: .ember, background: .ember.opacity(0.12)) { … }
struct SierraIconButton: View {

    let systemName: String
    var tint: Color = .white
    var background: Color? = nil
    var size: CGFloat = 20
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background {
                    if let background {
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(background)
                    }
                }
                .contentShape(Rectangle())
        }
    }
}

// MARK: - SierraFAB

/// Floating Action Button — ember fill, white icon, modal shadow.
///
///     SierraFAB { createTrip() }                          // icon-only circular
///     SierraFAB(label: "New Trip") { createTrip() }       // extended with label
///     SierraFAB(systemName: "car.fill") { addVehicle() }  // custom icon
struct SierraFAB: View {

    var systemName: String = "plus"
    var label: String? = nil
    let action: () -> Void

    private var isExtended: Bool { label != nil }

    var body: some View {
        Button(action: action) {
            Group {
                if let label {
                    // Extended FAB
                    HStack(spacing: 8) {
                        Image(systemName: systemName)
                            .font(.system(size: 18, weight: .semibold))
                        Text(label)
                            .font(SierraFont.body(15, weight: .semibold))
                    }
                    .padding(.horizontal, Spacing.lg)
                    .frame(height: 56)
                } else {
                    // Icon-only FAB
                    Image(systemName: systemName)
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 56, height: 56)
                }
            }
            .foregroundStyle(.white)
            .background(
                SierraTheme.Colors.ember,
                in: isExtended
                    ? AnyShape(RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous))
                    : AnyShape(Circle())
            )
            .sierraShadow(SierraTheme.Shadow.modal)
        }
    }
}
