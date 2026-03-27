import Foundation
import UIKit

enum CSVExportError: LocalizedError {
    case invalidCSVData
    case presenterUnavailable
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCSVData:
            return "Could not encode CSV content."
        case .presenterUnavailable:
            return "Could not open the share sheet."
        case .writeFailed(let error):
            return "Failed to prepare CSV for export: \(error.localizedDescription)"
        }
    }
}

enum CSVExportHelper {

    @MainActor
    static func presentShareSheet(csv: String, filename: String) throws {
        guard let data = csv.data(using: .utf8) else {
            throw CSVExportError.invalidCSVData
        }

        let safeFilename = filename.isEmpty ? "report.csv" : filename
        let baseName = URL(fileURLWithPath: safeFilename).deletingPathExtension().lastPathComponent
        let preferredBaseName = baseName.isEmpty ? "report" : baseName
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(preferredBaseName)-\(UUID().uuidString)")
            .appendingPathExtension("csv")

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw CSVExportError.writeFailed(error)
        }

        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: url)
        }

        guard let presenter = topMostViewController() else {
            throw CSVExportError.presenterUnavailable
        }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 1,
                height: 1
            )
            popover.permittedArrowDirections = []
        }

        presenter.present(activityVC, animated: true)
    }

    @MainActor
    private static func topMostViewController(
        base: UIViewController?
    ) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topMostViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topMostViewController(base: presented)
        }
        return base
    }

    @MainActor
    private static func topMostViewController() -> UIViewController? {
        topMostViewController(base: activeKeyWindow()?.rootViewController)
    }

    @MainActor
    private static func activeKeyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        let activeScene = scenes.first { $0.activationState == .foregroundActive }
        return activeScene?.windows.first(where: \.isKeyWindow)
            ?? scenes.first?.windows.first(where: \.isKeyWindow)
    }
}
