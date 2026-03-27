import SwiftUI

struct SierraConnectedToolbar<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            content
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.8)
        )
    }
}

struct SierraConnectedToolbarDivider: View {
    var body: some View {
        Divider()
            .frame(height: 24)
            .overlay(Color(.separator).opacity(0.35))
            .padding(.vertical, 4)
    }
}

struct SierraToolbarIconButtonLabel: View {
    let systemImage: String
    var isActive: Bool = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(isActive ? Color.accentColor : Color.primary)
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
    }
}

struct SierraSelectionMenuRow: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
            }
        }
    }
}
