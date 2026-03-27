import SwiftUI

// MARK: - SierraToggleRow

/// Branded toggle row with label, optional description, and ember tint.
///
///     SierraToggleRow(label: "Enable Notifications",
///                     description: "Get alerts for trip updates",
///                     isOn: $notificationsEnabled)
struct SierraToggleRow: View {

    let label: String
    var description: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .sierraStyle(.cardTitle)
                if let description {
                    Text(description)
                        .sierraStyle(.caption)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(SierraTheme.Colors.ember)
                .accessibilityLabel(label)
                .accessibilityHint(description ?? "Toggles \(label)")
        }
        .accessibilityElement(children: .combine)
        .padding(Spacing.md)
        .background(
            SierraTheme.Colors.cardSurface,
            in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
        )
    }
}
