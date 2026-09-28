// Renders the Lunet mark (a thick glass loupe with a cyan/pink/green refraction rim and a
// sparkle, resting on a small QR code and magnifying its top-left finder) into the PNGs a
// .pkpass bundle needs. Same geometry as the app icon (Lens/Resources/AppIcon.icon, 1024-point
// canvas).
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

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

/// The icon's light and dark appearances.
struct Appearance {
    var tile: CGColor
    var code: CGColor
    var disc: CGColor
    var finder: CGColor
    var rims: [CGColor] // link (top), travel, wifi (bottom)

    static let light = Appearance(
        tile: rgb(0xFFFFFF), code: rgb(0xBFC4CB), disc: rgb(0xE8F7FF), finder: rgb(0x1C1C1E),
        rims: [rgb(0x1FA6E0), rgb(0xFF2D55), rgb(0x2FC25B)]
    )
    static let dark = Appearance(
        tile: rgb(0x0E1116), code: rgb(0x434952), disc: rgb(0x15232E), finder: rgb(0xFFFFFF),
        rims: [rgb(0x64D2FF), rgb(0xFF375F), rgb(0x30D158)]
    )
}

/// Shadows are specified in device pixels, not user space: `shadow` scales icon units to them.
nonisolated(unsafe) var unitsToPixels: CGFloat = 1

func shadow(_ ctx: CGContext, y: CGFloat, blur: CGFloat, color: CGColor) {
    ctx.setShadow(offset: CGSize(width: 0, height: -y * unitsToPixels), blur: blur * unitsToPixels, color: color)
}

/// The QR code is centred on the 1024 canvas and the lens reaches toward the top-left (the
/// artwork spans 149...778); this square frames it, centred on the code like the icon.
let artBounds = CGRect(x: 144, y: 144, width: 736, height: 736)

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// A QR finder (7:5:3) of `size` with its top-left at `origin`, for an even-odd fill.
func finder(_ origin: CGPoint, _ size: CGFloat) -> CGPath {
    let ring = size / 7
    let outer = CGRect(origin: origin, size: CGSize(width: size, height: size))
    let p = CGMutablePath()
    p.addPath(roundedRect(outer, size * 0.2286))
    p.addPath(roundedRect(outer.insetBy(dx: ring, dy: ring), size * 0.0857))
    p.addPath(roundedRect(outer.insetBy(dx: ring * 2, dy: ring * 2), size * 0.0913))
    return p
}

/// Data modules as (column, row) on the 28-point grid starting at (472, 472).
let modules: [(Int, Int)] = [
    (6, 0), (9, 0), (3, 1), (5, 1), (10, 1), (5, 2), (6, 2), (8, 2), (10, 2),
    (1, 3), (3, 3), (4, 3), (5, 3), (7, 3), (2, 4), (3, 4), (4, 4), (7, 4), (8, 4), (9, 4), (10, 4),
    (2, 5), (3, 5), (4, 5), (5, 5), (1, 6), (6, 6), (7, 6), (8, 6), (10, 6),
    (0, 7), (1, 7), (2, 7), (3, 7), (4, 7), (5, 7), (6, 7), (7, 7), (8, 7), (9, 7),
    (1, 8), (2, 8), (3, 8), (4, 8), (5, 8), (10, 8), (0, 9), (1, 9), (2, 9), (4, 9), (5, 9), (8, 9), (10, 9),
    (4, 10), (5, 10), (6, 10), (10, 10),
]

func ring(_ cx: CGFloat, _ cy: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.addEllipse(in: CGRect(x: cx - 214, y: cy - 214, width: 428, height: 428))
    p.addEllipse(in: CGRect(x: cx - 172, y: cy - 172, width: 344, height: 344))
    return p
}

func sparkle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGPath {
    let k = r * 0.22
    let p = CGMutablePath()
    p.move(to: CGPoint(x: cx, y: cy - r))
    p.addQuadCurve(to: CGPoint(x: cx + r, y: cy), control: CGPoint(x: cx + k, y: cy - k))
    p.addQuadCurve(to: CGPoint(x: cx, y: cy + r), control: CGPoint(x: cx + k, y: cy + k))
    p.addQuadCurve(to: CGPoint(x: cx - r, y: cy), control: CGPoint(x: cx - k, y: cy + k))
    p.addQuadCurve(to: CGPoint(x: cx, y: cy - r), control: CGPoint(x: cx - k, y: cy - k))
    p.closeSubpath()
    return p
}

/// Draws the loupe on its code in 1024-point icon units (y down).
func drawLoupe(_ ctx: CGContext, _ a: Appearance) {
    // The code: two visible finders and the data modules (the third hides under the lens).
    ctx.setFillColor(a.code)
    ctx.addPath(finder(CGPoint(x: 582, y: 246), 196))
    ctx.addPath(finder(CGPoint(x: 246, y: 582), 196))
    ctx.fillPath(using: .evenOdd)
    for (column, row) in modules {
        let rect = CGRect(x: 472 + CGFloat(column) * 28, y: 472 + CGFloat(row) * 28, width: 24, height: 24)
        ctx.addPath(roundedRect(rect, 7.2))
    }
    ctx.fillPath()

    // The glass disc with a soft cyan halo, and the magnified finder inside it.
    ctx.saveGState()
    shadow(ctx, y: 6, blur: 44, color: a.rims[0].copy(alpha: 0.35)!)
    ctx.setFillColor(a.disc)
    ctx.fillEllipse(in: CGRect(x: 192, y: 192, width: 356, height: 356))
    ctx.restoreGState()
    ctx.saveGState()
    shadow(ctx, y: 5, blur: 14, color: rgb(0x000000, 0.25))
    ctx.addPath(finder(CGPoint(x: 254, y: 254), 240))
    ctx.setFillColor(a.finder)
    ctx.fillPath(using: .evenOdd)
    ctx.restoreGState()

    // Rims, bottom to top: green, pink, cyan (with a glassy highlight).
    ctx.saveGState()
    shadow(ctx, y: 6, blur: 20, color: rgb(0x000000, 0.12))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    let centres = [CGPoint(x: 363, y: 363), CGPoint(x: 379, y: 372), CGPoint(x: 371, y: 380)]
    for i in [2, 1, 0] {
        ctx.addPath(ring(centres[i].x, centres[i].y))
        ctx.setFillColor(a.rims[i])
        ctx.fillPath(using: .evenOdd)
    }
    ctx.endTransparencyLayer()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(ring(363, 363))
    ctx.clip(using: .evenOdd)
    let sheen = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [rgb(0xFFFFFF, 0.45), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 0.6])!
    ctx.drawLinearGradient(sheen, start: CGPoint(x: 149, y: 149), end: CGPoint(x: 450, y: 450), options: [])
    ctx.restoreGState()

    // The sparkle.
    ctx.saveGState()
    shadow(ctx, y: 2, blur: 12, color: rgb(0x000000, 0.22))
    ctx.addPath(sparkle(270, 266, 54))
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()
}

/// A `side`×`side` tile with the mark. `share` is the artwork's share of the tile's width.
func render(side: Int, appearance: Appearance, rounded: Bool, share: CGFloat) -> CGImage {
    let s = CGFloat(side)
    let ctx = CGContext(
        data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    // Work in y-down coordinates, like the icon's SVG layers.
    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1)

    ctx.setFillColor(appearance.tile)
    if rounded {
        ctx.addPath(roundedRect(CGRect(x: 0, y: 0, width: s, height: s), s * 0.225))
        ctx.fillPath()
    } else {
        ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))
    }

    let scale = s * share / artBounds.width
    unitsToPixels = scale
    ctx.translateBy(x: s / 2, y: s / 2)
    ctx.scaleBy(x: scale, y: scale)
    ctx.translateBy(x: -artBounds.midX, y: -artBounds.midY)
    drawLoupe(ctx, appearance)
    return ctx.makeImage()!
}

func write(_ img: CGImage, _ name: String) {
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    precondition(CGImageDestinationFinalize(dest), "failed to write \(name)")
    print("wrote \(url.path)")
}

// icon.png: 29pt (lock screen / notifications). Full-bleed light icon; iOS applies its own mask.
for (scale, suffix) in [(1, ""), (2, "@2x"), (3, "@3x")] {
    write(render(side: 29 * scale, appearance: .light, rounded: false, share: 0.72 * 736 / 648), "icon\(suffix).png")
}
// logo.png: shown top-left of the pass next to logoText "Lunet". Max 160×50pt; we use a 50pt
// tile in the dark appearance so it reads on every pass colour.
for (scale, suffix) in [(1, ""), (2, "@2x"), (3, "@3x")] {
    write(render(side: 50 * scale, appearance: .dark, rounded: true, share: 0.8), "logo\(suffix).png")
}
