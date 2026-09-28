import CoreImage.CIFilterBuiltins
import UIKit

// OWNER: Create module. Result ("Show code") and History call this. Keep signature stable.
enum CodeRenderer {
    /// A crisp, plain rendering of any supported code, `dimension` points wide.
    static func image(raw: String, symbology: Symbology, dimension: CGFloat) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(raw.utf8)
        guard let output = filter.outputImage else { return nil }
        let scale = dimension * 3 / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg, scale: 3, orientation: .up)
    }
}
