import SwiftUI

// MARK: - SierraPickerRow

/// Tappable row that opens a picker/sheet - chevron affordance on the right.
///
///     SierraPickerRow(label: "Fuel Type", value: "Diesel") { showFuelPicker = true }
struct SierraPickerRow: View {

    let label: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(SierraFont.subheadline)
                    .foregroundStyle(SierraTheme.Colors.primaryText)

                Spacer()

                Text(value)
                    .font(SierraFont.subheadline)
                    .foregroundStyle(SierraTheme.Colors.granite)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(SierraTheme.Colors.granite)
            }
            .padding(Spacing.md)
            .background(
                SierraTheme.Colors.cardSurface,
                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            )
        }
    }
}
