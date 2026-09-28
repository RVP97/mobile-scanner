import ImageIO
import UIKit

/// Prepares logo artwork: SF Symbols as grayscale masks (so they take the code's paint) and
/// photos as small square crops that are cheap to store inside a style.
enum LogoImages {
    private static var glyphCache: [String: CGImage] = [:]

    /// White glyph on black, DeviceGray, no alpha: the format `CGContext.clip(to:mask:)` expects.
    static func glyphMask(_ symbolName: String) -> CGImage? {
        if let cached = glyphCache[symbolName] { return cached }
        let configuration = UIImage.SymbolConfiguration(pointSize: 240, weight: .semibold)
        guard let symbol = UIImage(systemName: symbolName, withConfiguration: configuration)?
            .withTintColor(.white, renderingMode: .alwaysOriginal) else { return nil }
        let width = Int(symbol.size.width.rounded(.up)), height = Int(symbol.size.height.rounded(.up))
        guard width > 0, height > 0, let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(context)
        symbol.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        let image = context.makeImage()
        glyphCache[symbolName] = image
        return image
    }

    nonisolated static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// Centre-square crop, 512 px, JPEG. Keeps saved styles small.
    nonisolated static func preparePhoto(_ data: Data) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1024,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let side = min(image.width, image.height)
        let crop = CGRect(x: (image.width - side) / 2, y: (image.height - side) / 2, width: side, height: side)
        guard let square = image.cropping(to: crop) else { return nil }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512), format: {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            return format
        }())
        return renderer.jpegData(withCompressionQuality: 0.85) { _ in
            UIImage(cgImage: square).draw(in: CGRect(x: 0, y: 0, width: 512, height: 512))
        }
    }
}
