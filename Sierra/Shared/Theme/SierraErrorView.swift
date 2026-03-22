import SwiftUI

// MARK: - SierraErrorView
// Phase 12: Reusable error state with retry button.
// Used throughout the app when data loading fails.

struct SierraErrorView: View {

    let message: String
    var retryAction: (() async -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(SierraTheme.Colors.granite)
                .frame(width: 80, height: 80)
                .background(
                    SierraTheme.Colors.snowfield,
                    in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                )

            VStack(spacing: Spacing.xxs) {
                Text("Failed to Load")
                    .sierraStyle(.sectionHeader)
                Text(message)
                    .sierraStyle(.secondaryBody)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxl)
            }

            if let retryAction {
                SierraButton.primary("Retry") {
                    Task { await retryAction() }
                }
                .padding(.horizontal, Spacing.section)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
