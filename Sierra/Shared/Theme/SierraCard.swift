import SwiftUI

// MARK: - SierraCard

/// Base card wrapper used by every data-display card in the app.
/// Provides consistent corner radius, shadow, background, and optional left accent border.
///
///     SierraCard { VStack { … } }
///     SierraCard(borderAccentColor: status.dotColor) { … }
struct SierraCard<Content: View>: View {

    let content: () -> Content
    var padding: CGFloat = Spacing.lg
    var hasShadow: Bool = true
    var borderAccentColor: Color? = nil
    var backgroundColor: Color = SierraTheme.Colors.cardSurface

    init(
        padding: CGFloat = Spacing.lg,
        hasShadow: Bool = true,
        borderAccentColor: Color? = nil,
        backgroundColor: Color = SierraTheme.Colors.cardSurface,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.hasShadow = hasShadow
        self.borderAccentColor = borderAccentColor
        self.backgroundColor = backgroundColor
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor, in: cardShape)
            .overlay(alignment: .leading) {
                if let borderAccentColor {
                    UnevenRoundedRectangle(
                        topLeadingRadius: Radius.card,
                        bottomLeadingRadius: Radius.card,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                    .fill(borderAccentColor)
                    .frame(width: 3)
                }
            }
            .clipShape(cardShape)
            .if(hasShadow) { view in
                view.sierraShadow(SierraTheme.Shadow.card)
            }
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
    }
}

// MARK: - Conditional Modifier Helper

private extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - View + sierraCard Modifier

extension View {
    /// Wraps the view in a `SierraCard` with optional accent border and shadow.
    func sierraCard(accent: Color? = nil, shadow: Bool = true) -> some View {
        SierraCard(hasShadow: shadow, borderAccentColor: accent) { self }
    }
}
