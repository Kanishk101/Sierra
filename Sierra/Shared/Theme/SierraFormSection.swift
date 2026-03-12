import SwiftUI

// MARK: - SierraFormSection

/// Groups form fields under a titled section with optional subtitle.
///
///     SierraFormSection(title: "Vehicle Info", subtitle: "Enter basic details") {
///         SierraTextField(...)
///         SierraTextField(...)
///     }
struct SierraFormSection<Content: View>: View {

    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .sierraStyle(.sectionHeader)
                if let subtitle {
                    Text(subtitle)
                        .sierraStyle(.secondaryBody)
                }
            }

            content()
        }
        .padding(.bottom, Spacing.xl)
    }
}

// MARK: - SierraFormDivider

/// Thin divider in adaptive color with an optional centered label.
///
///     SierraFormDivider()
///     SierraFormDivider(label: "OR")
struct SierraFormDivider: View {

    var label: String? = nil

    var body: some View {
        HStack(spacing: Spacing.xs) {
            line
            if let label {
                Text(label)
                    .textCase(.uppercase)
                    .font(SierraFont.caption2)
                    .foregroundStyle(SierraTheme.Colors.granite)
                    .tracking(1.5)
                    .padding(.horizontal, Spacing.xs)
                line
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private var line: some View {
        Rectangle()
            .fill(SierraTheme.Colors.divider)
            .frame(height: 1)
    }
}
