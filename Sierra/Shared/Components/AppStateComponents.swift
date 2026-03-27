import SwiftUI

// MARK: - Fallback Error Banner
/// Dismissible inline error banner — red background, icon + text + close.
/// Used throughout driver views for non-blocking partial-load errors.
struct AppFallbackErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(SierraFont.caption2.weight(.bold))
                .foregroundColor(.white)

            Text(message)
                .font(SierraFont.footnote.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(2)

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(SierraFont.callout.weight(.bold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss error")
        }
        .accessibilityElement(children: .combine)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.86, green: 0.24, blue: 0.20))
        )
    }
}

// MARK: - Empty State Card
/// Branded empty-state placeholder with icon, title, subtitle, and CTA.
struct AppEmptyStateCard: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray.fill")
                .font(SierraFont.scaled(30))
                .foregroundColor(.appTextSecondary.opacity(0.5))

            Text(title)
                .font(SierraFont.title3)
                .foregroundColor(.appTextPrimary)

            Text(subtitle)
                .font(SierraFont.footnote)
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)

            Button(action: action) {
                Text(actionTitle)
                    .font(SierraFont.body(14, weight: .bold))
                    .foregroundColor(.appOrange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.appOrange.opacity(0.12))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.appOrange.opacity(0.25), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(actionTitle)
        }
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.appCardBg)
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.appDivider.opacity(0.6), lineWidth: 1)
        )
    }
}
