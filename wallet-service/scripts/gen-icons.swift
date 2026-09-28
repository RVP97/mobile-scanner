// Renders the Lens mark (four rounded viewfinder corner brackets + a centre lens dot,
// cyan #64D2FF on near-black) into the PNGs a .pkpass bundle needs.
//
//   swift scripts/gen-icons.swift assets
//
// Then `node scripts/embed-assets.mjs` inlines them into src/assets.generated.ts.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets"
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let cyan = CGColor(srgbRed: 0x64 / 255, green: 0xD2 / 255, blue: 0xFF / 255, alpha: 1)
let ink = CGColor(srgbRed: 0x0E / 255, green: 0x11 / 255, blue: 0x16 / 255, alpha: 1)

/// Draws the mark into a `side`×`side` square. `tile` adds the rounded near-black backdrop.
func render(side: Int, tile: Bool, fullBleed: Bool) -> CGImage {
    let s = CGFloat(side)
    let ctx = CGContext(
        data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    if tile {
        ctx.setFillColor(ink)
        if fullBleed {
            ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))
        } else {
            let r = s * 0.225
            ctx.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s), cornerWidth: r, cornerHeight: r, transform: nil))
            ctx.fillPath()
        }
    }

    // Viewfinder brackets.
    let inset = s * 0.2
    let box = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let arm = box.width * 0.3
    let lw = max(1.5, s * 0.075)
    let corner = box.width * 0.16
    ctx.setStrokeColor(cyan)
    ctx.setLineWidth(lw)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    func bracket(_ origin: CGPoint, _ dx: CGFloat, _ dy: CGFloat) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: origin.x, y: origin.y + dy * arm))
        p.addLine(to: CGPoint(x: origin.x, y: origin.y + dy * corner))
        p.addQuadCurve(to: CGPoint(x: origin.x + dx * corner, y: origin.y), control: origin)
        p.addLine(to: CGPoint(x: origin.x + dx * arm, y: origin.y))
        ctx.addPath(p)
        ctx.strokePath()
    }
    bracket(CGPoint(x: box.minX, y: box.minY), 1, 1)
    bracket(CGPoint(x: box.maxX, y: box.minY), -1, 1)
    bracket(CGPoint(x: box.minX, y: box.maxY), 1, -1)
    bracket(CGPoint(x: box.maxX, y: box.maxY), -1, -1)

    // Lens dot.
    let d = box.width * 0.26
    ctx.setFillColor(cyan)
    ctx.fillEllipse(in: CGRect(x: s / 2 - d / 2, y: s / 2 - d / 2, width: d, height: d))

    return ctx.makeImage()!
}

func write(_ img: CGImage, _ name: String) {
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    precondition(CGImageDestinationFinalize(dest), "failed to write \(name)")
    print("wrote \(url.path)")
}

// icon.png: 29pt (lock screen / notifications). Full-bleed; iOS applies its own mask.
for (scale, suffix) in [(1, ""), (2, "@2x"), (3, "@3x")] {
    write(render(side: 29 * scale, tile: true, fullBleed: true), "icon\(suffix).png")
}
// logo.png: shown top-left of the pass next to logoText "Lens". Max 160×50pt; we use a 50pt tile.
for (scale, suffix) in [(1, ""), (2, "@2x"), (3, "@3x")] {
    write(render(side: 50 * scale, tile: true, fullBleed: false), "logo\(suffix).png")
}
