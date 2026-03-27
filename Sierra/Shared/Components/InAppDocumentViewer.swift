import SwiftUI
import SafariServices

struct InAppDocumentViewer: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        if #unavailable(iOS 26.0) {
            controller.preferredControlTintColor = .systemOrange
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
