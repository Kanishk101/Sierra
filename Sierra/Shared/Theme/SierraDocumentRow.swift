import SwiftUI

// MARK: - SierraDocumentRow

/// Row for vehicle document monitoring (insurance, registration, license).
///
///     SierraDocumentRow(documentName: "Insurance", expiryDate: "Mar 19, 2026",
///                       status: .expiringSoon) { showDocDetail() }
struct SierraDocumentRow: View {

    let documentName: String
    let expiryDate: String
    let status: DocumentStatus
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {

                // ── Document icon ──
                Image(systemName: iconName)
                    .font(SierraFont.scaled(20))
                    .foregroundStyle(status.dotColor)
                    .frame(width: 36, height: 36)
                    .background(
                        status.backgroundColor,
                        in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    )

                // ── Name + expiry ──
                VStack(alignment: .leading, spacing: 2) {
                    Text(documentName)
                        .sierraStyle(.cardTitle)
                    Text("Expires: \(expiryDate)")
                        .sierraStyle(.caption)
                }

                Spacer()

                // ── Status badge + chevron ──
                HStack(spacing: Spacing.xs) {
                    SierraBadge(status, size: .compact)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(SierraTheme.Colors.granite)
                }
            }
            .padding(Spacing.md)
            .background(
                SierraTheme.Colors.cardSurface,
                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(documentName)
        .accessibilityValue("Expires \(expiryDate), \(status.label)")
        .accessibilityHint("Opens document details")
    }

    // MARK: - Icon Mapping

    private var iconName: String {
        switch status {
        case .valid:        "checkmark.shield.fill"
        case .expiringSoon: "exclamationmark.triangle.fill"
        case .expired:      "xmark.shield.fill"
        case .missing:      "doc.questionmark.fill"
        }
    }
}
