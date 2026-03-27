import SwiftUI

// MARK: - SierraSearchBar

/// Branded search bar with clear button and optional submit action.
///
///     SierraSearchBar(text: $searchText, placeholder: "Search vehicles…")
struct SierraSearchBar: View {

    @Binding var text: String
    var placeholder: String = "Search…"
    var onSubmit: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(SierraFont.scaled(15))
                .foregroundStyle(SierraTheme.Colors.granite)

            TextField(placeholder, text: $text)
                .font(SierraFont.bodyText)
                .foregroundStyle(SierraTheme.Colors.primaryText)
                .focused($isFocused)
                .onSubmit { onSubmit?() }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(SierraFont.scaled(16))
                        .foregroundStyle(SierraTheme.Colors.granite)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            SierraTheme.Colors.cardSurface,
            in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .strokeBorder(
                    isFocused ? SierraTheme.Colors.ember : SierraTheme.Colors.cloud,
                    lineWidth: 1.5
                )
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}
