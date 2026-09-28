import UIKit

// OWNER: Create module. Result ("Show code") and History call this. Keep signature stable.
enum CodeRenderer {
    /// A crisp, plain rendering of any supported code, `dimension` points wide.
    static func image(raw: String, symbology: Symbology, dimension: CGFloat) -> UIImage? {
        guard let scene = plainScene(raw: raw, symbology: symbology) else { return nil }
        let scale: CGFloat = 3
        return SceneRenderer.image(scene, pixelWidth: Int(dimension * scale), backdrop: .white)
            .map { UIImage(cgImage: $0, scale: scale, orientation: .up) }
    }

    /// Black on white with digits, no styling. Formats Lens reads but doesn't make are drawn in
    /// the closest format it does make, so "Show code" always has something to show.
    static func plainScene(raw: String, symbology: Symbology) -> ArtworkScene? {
        let target: Symbology = switch symbology {
        case .microQR: .qr
        case .microPDF417: .pdf417
        case .code93, .gs1DataBar: raw.allSatisfy(\.isASCII) ? .code128 : .qr
        default: symbology
        }
        let value = SymbologyValidator.check(raw, for: target).value ?? raw
        guard let graphic = CodeEncoder.encode(value, as: target) ?? CodeEncoder.encode(raw, as: .qr) else { return nil }
        return SceneBuilder.scene(for: SceneInput(graphic: graphic, style: CodeStyle()))
    }
}
