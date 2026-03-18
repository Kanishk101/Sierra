import SwiftUI

/// Slide-down notification banner overlay — auto-dismisses after 4 seconds.
/// Tapping the banner dismisses immediately and triggers the onTap callback.
struct NotificationBannerView: View {
    let title: String
    let message: String
    let onTap: () -> Void

    var body: some View {
        VStack {
            bannerContent
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
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .onTapGesture { onTap() }
    }
}

// MARK: - BannerCoordinator

/// Queue-based banner manager — shows one banner at a time, auto-dismisses after 4s.
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
        queue.append(banner)
        if current == nil { showNext() }
    }

    private func showNext() {
        guard !queue.isEmpty else {
            current = nil
            return
        }
        current = queue.removeFirst()
        dismissTask?.cancel()
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
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
