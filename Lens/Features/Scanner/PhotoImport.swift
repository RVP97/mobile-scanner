import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// Presents the system photo picker from whatever is frontmost in the window.
///
/// Home and the scanner cover can each be under a sheet, so a SwiftUI `photosPicker` attached to them
/// would try to present from a controller that is already presenting. Going through UIKit lets it
/// present on top of whatever is showing instead.
enum PhotoImport {
    /// - Parameter window: The window to present in; nil uses the app's key window.
    static func pickImage(from window: UIWindow?) async -> Data? {
        let window = window ?? UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        guard var presenter = window?.rootViewController else { return nil }
        while let next = presenter.presentedViewController, !next.isBeingDismissed {
            presenter = next
        }

        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        let delegate = PickerDelegate()
        picker.delegate = delegate
        picker.presentationController?.delegate = delegate

        let data: Data? = await withCheckedContinuation { continuation in
            delegate.onFinish = { provider in
                guard let provider else { return continuation.resume(returning: nil) }
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    continuation.resume(returning: data)
                }
            }
            presenter.present(picker, animated: true)
        }
        withExtendedLifetime(delegate) {}
        return data
    }

    private final class PickerDelegate: NSObject, PHPickerViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
        var onFinish: ((NSItemProvider?) -> Void)?

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            onFinish?(results.first?.itemProvider)
            onFinish = nil
        }

        /// Swiping the picker away doesn't go through `didFinishPicking`.
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            onFinish?(nil)
            onFinish = nil
        }
    }
}
