import SwiftUI

/// Slide-down notification banner overlay.
/// Auto-dismisses after 4 seconds.
/// Can be dismissed immediately by tapping OR swiping up.
struct NotificationBannerView: View {
    let title: String
    let message: String
    let onTap: () -> Void
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false

    var body: some View {
        VStack {
            bannerContent
                .offset(y: min(0, dragOffset))  // only allow upward swipe
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            // Only track upward swipes (negative y)
                            if value.translation.height < 0 {
                                dragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            if value.translation.height < -30 {
                                // Swiped up far enough — dismiss
                                withAnimation(.easeOut(duration: 0.22)) { dragOffset = -200 }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { onDismiss() }
                            } else {
                                // Snap back
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragOffset = 0 }
                            }
                        }
                )
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var bannerContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.title3)
                .foregroundStyle(SierraTheme.Colors.ember)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(message).font(.caption).lineLimit(2).foregroundStyle(.secondary)
            }
            Spacer()
            // Swipe hint
            Image(systemName: "chevron.up")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .onTapGesture { onTap() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(title)
        .accessibilityHint("Opens notification")
    }
}

// MARK: - BannerCoordinator
@Observable
final class BannerCoordinator {
    struct Banner: Identifiable {
        let id = UUID()
        let title: String
        let body: String
        var onTap: () -> Void = {}
    }
    var current: Banner? = nil
    private var queue: [Banner] = []
    private var dismissTask: Task<Void, Never>? = nil

    func show(_ banner: Banner) {
        if let current, current.title == banner.title, current.body == banner.body { return }
        if queue.contains(where: { $0.title == banner.title && $0.body == banner.body }) { return }
        queue.append(banner)
        if current == nil { showNext() }
    }
    private func showNext() {
        guard !queue.isEmpty else { current = nil; return }
        current = queue.removeFirst()
        dismissTask?.cancel()
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { self?.current = nil }
            self?.showNext()
        }
    }
    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.3)) { current = nil }
        showNext()
    }
}
