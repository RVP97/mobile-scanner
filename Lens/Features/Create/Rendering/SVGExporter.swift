import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Writes an `ArtworkScene` as a standalone SVG document (paths, gradients, text, embedded PNG logos).
nonisolated enum SVGExporter {
    static func svg(_ scene: ArtworkScene) -> String {
        var defs: [String] = []
        var body: [String] = []
        var nextID = 0
        func makeID(_ prefix: String) -> String {
            nextID += 1
            return "\(prefix)\(nextID)"
        }

        func fillAttribute(_ paint: ArtworkScene.Paint) -> String {
            switch paint {
            case .solid(let color):
                return colorAttributes(color, prefix: "fill")
            case .linear(let from, let to, let start, let end):
                let id = makeID("g")
                defs.append(
                    #"<linearGradient id="\#(id)" gradientUnits="userSpaceOnUse" x1="\#(n(start.x))" y1="\#(n(start.y))" x2="\#(n(end.x))" y2="\#(n(end.y))">"#
                        + #"<stop offset="0" \#(colorAttributes(from, prefix: "stop-color"))/>"#
                        + #"<stop offset="1" \#(colorAttributes(to, prefix: "stop-color"))/></linearGradient>"#
                )
                return #"fill="url(#\#(id))""#
            }
        }

        for item in scene.items {
            switch item {
            case .fill(let path, let paint, let evenOdd):
                let rule = evenOdd ? #" fill-rule="evenodd""# : ""
                body.append(#"<path d="\#(pathData(path))" \#(fillAttribute(paint))\#(rule)/>"#)

            case .mask(let mask, let rect, let paint):
                guard let png = pngBase64(mask) else { continue }
                let id = makeID("m")
                let frame = #"x="\#(n(rect.minX))" y="\#(n(rect.minY))" width="\#(n(rect.width))" height="\#(n(rect.height))""#
                defs.append(#"<mask id="\#(id)" maskUnits="userSpaceOnUse" \#(frame)><image \#(frame) href="data:image/png;base64,\#(png)"/></mask>"#)
                body.append(#"<rect \#(frame) \#(fillAttribute(paint)) mask="url(#\#(id))"/>"#)

            case .stroke(let path, let color, let width):
                body.append(#"<path d="\#(pathData(path))" fill="none" \#(colorAttributes(color, prefix: "stroke")) stroke-width="\#(n(width))"/>"#)

            case .text(let text):
                let family = text.monospaced
                    ? "ui-monospace, 'SF Mono', Menlo, monospace"
                    : "-apple-system, 'SF Pro Text', 'Helvetica Neue', Helvetica, Arial, sans-serif"
                body.append(
                    #"<text x="\#(n(text.rect.midX))" y="\#(n(text.baseline.y))" text-anchor="middle" font-family="\#(family)" "#
                        + #"font-size="\#(n(text.fontSize))" font-weight="\#(fontWeight(text.weight))" \#(colorAttributes(text.color, prefix: "fill"))>"#
                        + escape(text.string) + "</text>"
                )

            case .image(let image, let rect, let clip):
                guard let png = pngBase64(image) else { continue }
                var clipAttribute = ""
                if let clip {
                    let id = makeID("c")
                    defs.append(#"<clipPath id="\#(id)"><path d="\#(pathData(clip))"/></clipPath>"#)
                    clipAttribute = #" clip-path="url(#\#(id))""#
                }
                body.append(
                    #"<image x="\#(n(rect.minX))" y="\#(n(rect.minY))" width="\#(n(rect.width))" height="\#(n(rect.height))" "#
                        + #"preserveAspectRatio="xMidYMid slice" href="data:image/png;base64,\#(png)"\#(clipAttribute)/>"#
                )
            }
        }

        let w = n(scene.size.width), h = n(scene.size.height)
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(w) \(h)" width="\(w)" height="\(h)">
        \(defs.isEmpty ? "" : "<defs>\(defs.joined())</defs>\n")\(body.joined(separator: "\n"))
        </svg>

        """
    }

    // MARK: Helpers

    /// Compact number formatting: up to three decimals, no trailing zeros.
    static func n(_ value: CGFloat) -> String {
        let rounded = (Double(value) * 1000).rounded() / 1000
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(format: "%.3f", rounded)
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
    }

    static func pathData(_ path: CGPath) -> String {
        var parts: [String] = []
        path.applyWithBlock { pointer in
            let element = pointer.pointee
            let p = element.points
            switch element.type {
            case .moveToPoint: parts.append("M\(n(p[0].x)) \(n(p[0].y))")
            case .addLineToPoint: parts.append("L\(n(p[0].x)) \(n(p[0].y))")
            case .addQuadCurveToPoint: parts.append("Q\(n(p[0].x)) \(n(p[0].y)) \(n(p[1].x)) \(n(p[1].y))")
            case .addCurveToPoint: parts.append("C\(n(p[0].x)) \(n(p[0].y)) \(n(p[1].x)) \(n(p[1].y)) \(n(p[2].x)) \(n(p[2].y))")
            case .closeSubpath: parts.append("Z")
            @unknown default: break
            }
        }
        return parts.joined()
    }

    private static func colorAttributes(_ color: RGBAColor, prefix: String) -> String {
        let opacityName = prefix == "stop-color" ? "stop-opacity" : "\(prefix)-opacity"
        let base = #"\#(prefix)="\#(color.hexString)""#
        return color.alpha < 1 ? base + #" \#(opacityName)="\#(n(color.alpha))""# : base
    }

    private static func fontWeight(_ weight: CodeStyle.CaptionWeight) -> Int {
        switch weight {
        case .regular: 400
        case .medium: 500
        case .semibold: 600
        case .bold: 700
        case .heavy: 800
        }
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func pngBase64(_ image: CGImage) -> String? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return (data as Data).base64EncodedString()
    }
}
