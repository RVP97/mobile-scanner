import LinkPresentation
import UIKit

/// Page title and icon for a link, via LinkPresentation. Only used after the deep check allows it.
struct LinkPreview: Hashable {
    var title: String?
    var icon: UIImage?
}

enum LinkPreviewLoader {
    static func load(_ url: URL) async -> LinkPreview? {
        let provider = LPMetadataProvider()
        provider.timeout = 6
        guard let metadata = try? await provider.startFetchingMetadata(for: url) else { return nil }
        let title = metadata.title?.trimmed
        let icon = await image(from: metadata.iconProvider)
        guard title?.isEmpty == false || icon != nil else { return nil }
        return LinkPreview(title: title, icon: icon)
    }

    private static func image(from provider: NSItemProvider?) async -> UIImage? {
        guard let provider, provider.canLoadObject(ofClass: UIImage.self) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                continuation.resume(returning: object as? UIImage)
            }
        }
    }
}
