import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Draws an `ArtworkScene` with Core Graphics: into a SwiftUI `Canvas`, a bitmap, or a vector PDF.
/// Everything here is thread-safe and runs off the main actor for exports and verification.
nonisolated enum SceneRenderer {
    private static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    /// Draws `scene` aspect-fit and centred in `rect` of a top-left-origin context.
    static func draw(_ scene: ArtworkScene, in context: CGContext, rect: CGRect) {
        guard scene.size.width > 0, scene.size.height > 0 else { return }
        let scale = min(rect.width / scene.size.width, rect.height / scene.size.height)
        context.saveGState()
        context.translateBy(
            x: rect.midX - scene.size.width * scale / 2,
            y: rect.midY - scene.size.height * scale / 2
        )
        context.scaleBy(x: scale, y: scale)
        for item in scene.items { draw(item, in: context) }
        context.restoreGState()
    }

    private static func draw(_ item: ArtworkScene.Item, in context: CGContext) {
        switch item {
        case .fill(let path, let paint, let evenOdd):
            context.saveGState()
            context.addPath(path)
            context.clip(using: evenOdd ? .evenOdd : .winding)
            fill(paint, bounds: path.boundingBoxOfPath, in: context)
            context.restoreGState()

        case .mask(let mask, let rect, let paint):
            context.saveGState()
            // Masks are sampled bottom-up; flip locally so the glyph stays upright.
            context.translateBy(x: rect.minX, y: rect.maxY)
            context.scaleBy(x: 1, y: -1)
            let local = CGRect(origin: .zero, size: rect.size)
            context.clip(to: local, mask: mask)
            context.scaleBy(x: 1, y: -1)
            context.translateBy(x: -rect.minX, y: -rect.maxY)
            fill(paint, bounds: rect, in: context)
            context.restoreGState()

        case .stroke(let path, let color, let width):
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(width)
            context.addPath(path)
            context.strokePath()

        case .text(let text):
            let line = text.line()
            let origin = text.baseline
            context.saveGState()
            context.textMatrix = .identity
            context.translateBy(x: origin.x, y: origin.y)
            context.scaleBy(x: 1, y: -1)
            context.textPosition = .zero
            CTLineDraw(line, context)
            context.restoreGState()

        case .image(let image, let rect, let clip):
            context.saveGState()
            if let clip {
                context.addPath(clip)
                context.clip()
            }
            context.interpolationQuality = .high
            context.translateBy(x: rect.minX, y: rect.maxY)
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(origin: .zero, size: rect.size))
            context.restoreGState()
        }
    }

    /// Fills the current clip with `paint`.
    private static func fill(_ paint: ArtworkScene.Paint, bounds: CGRect, in context: CGContext) {
        switch paint {
        case .solid(let color):
            context.setFillColor(color.cgColor)
            context.fill(bounds.insetBy(dx: -1, dy: -1))
        case .linear(let from, let to, let start, let end):
            guard let gradient = CGGradient(colorsSpace: sRGB, colors: [from.cgColor, to.cgColor] as CFArray, locations: [0, 1]) else { return }
            context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
    }

    // MARK: Bitmap

    /// Renders `pixelWidth` pixels wide. `backdrop` fills behind the scene (for verification and
    /// opaque exports); `nil` keeps transparency.
    static func image(_ scene: ArtworkScene, pixelWidth: Int, backdrop: RGBAColor? = nil) -> CGImage? {
        guard scene.size.width > 0 else { return nil }
        let width = max(pixelWidth, 1)
        let height = max(Int((CGFloat(width) * scene.size.height / scene.size.width).rounded()), 1)
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        if let backdrop {
            context.setFillColor(backdrop.cgColor)
            context.fill(bounds)
        }
        draw(scene, in: context, rect: bounds)
        return context.makeImage()
    }

    static func pngData(_ scene: ArtworkScene, pixelWidth: Int) -> Data? {
        guard let image = image(scene, pixelWidth: pixelWidth) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    // MARK: PDF

    /// A single-page vector PDF, `pointWidth` wide (72 pt = 1 inch).
    static func pdfData(_ scene: ArtworkScene, pointWidth: CGFloat = 288) -> Data {
        let data = NSMutableData()
        let height = pointWidth * scene.size.height / max(scene.size.width, 1)
        var box = CGRect(x: 0, y: 0, width: pointWidth, height: height)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }
        context.beginPDFPage(nil)
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1, y: -1)
        draw(scene, in: context, rect: box)
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }
}
