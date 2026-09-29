import UIKit

/// Draws a saved code the way its owner styled it, or plain when it has no style.
enum CodeArtwork {
    /// - Parameter includesFrame: Off for thumbnails, where a poster frame and caption would be noise.
    static func image(
        raw: String,
        symbology: Symbology,
        style: CodeStyle?,
        dimension: CGFloat,
        includesFrame: Bool = true
    ) -> UIImage? {
        guard var style else {
            return CodeRenderer.image(raw: raw, symbology: symbology, dimension: dimension)
        }
        if !includesFrame {
            style.frame = .none
            style.caption = ""
        }
        let document = CodeDocument(
            raw: raw,
            symbology: symbology,
            payload: PayloadParser.parse(raw, symbology: symbology),
            title: "",
            caption: style.caption
        )
        let scale: CGFloat = 3
        guard let scene = StudioModel(document: document, style: style).scene,
              let image = SceneRenderer.image(scene, pixelWidth: Int(dimension * scale), backdrop: style.backgroundColor ?? .white)
        else {
            return CodeRenderer.image(raw: raw, symbology: symbology, dimension: dimension)
        }
        return UIImage(cgImage: image, scale: scale, orientation: .up)
    }

    static func image(for item: ShowCodeItem, dimension: CGFloat, includesFrame: Bool = true) -> UIImage? {
        image(raw: item.raw, symbology: item.symbology, style: item.style, dimension: dimension, includesFrame: includesFrame)
    }
}
