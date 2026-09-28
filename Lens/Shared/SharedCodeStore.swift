import UIKit
import WidgetKit

/// The one created code the user pinned to the "My Code" widget. The app writes it into the
/// App Group container; the widget reads it. Nothing else is shared.
enum SharedCodeStore {
    struct PinnedCode {
        var image: UIImage
        var title: String
    }

    /// Widget kind of the "My Code" widget, reloaded whenever the pinned code changes.
    static let widgetKind = "com.rvp97.scanner.my-code"

    /// Widgets have a tight memory budget; the pinned image never needs more pixels than this.
    static let maxPixelSide: CGFloat = 720

    /// Pins a rendered code to the "My Code" widget, replacing the previous one.
    static func setPinnedCode(image: UIImage, title: String) {
        guard let folder, let png = downscaled(image).pngData() else { return }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try png.write(to: folder.appending(path: imageFile), options: .atomic)
            try Data(title.utf8).write(to: folder.appending(path: titleFile), options: .atomic)
        } catch {
            return
        }
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }

    static func clearPinnedCode() {
        guard let folder else { return }
        try? FileManager.default.removeItem(at: folder)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }

    static func pinnedCode() -> PinnedCode? {
        guard let folder,
              let image = UIImage(contentsOfFile: folder.appending(path: imageFile).path(percentEncoded: false)),
              let titleData = try? Data(contentsOf: folder.appending(path: titleFile))
        else { return nil }
        return PinnedCode(image: image, title: String(decoding: titleData, as: UTF8.self))
    }

    // MARK: Private

    private static let imageFile = "code.png"
    private static let titleFile = "title.txt"

    private static var folder: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: LensShared.appGroup)?
            .appending(path: "PinnedCode", directoryHint: .isDirectory)
    }

    private static func downscaled(_ image: UIImage) -> UIImage {
        let side = max(image.size.width, image.size.height) * image.scale
        guard side > maxPixelSide else { return image }
        let factor = maxPixelSide / side
        let size = CGSize(width: image.size.width * image.scale * factor, height: image.size.height * image.scale * factor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            // Codes are pixel art; keep module edges crisp.
            context.cgContext.interpolationQuality = .none
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
