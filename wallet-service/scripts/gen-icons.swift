// Renders the Ojito mark (an almond eye whose iris is five translucent blades in the kind
// colours, with a QR finder pattern for a pupil) into the PNGs a .pkpass bundle needs. Same
// geometry as the app icon (Lens/Resources/AppIcon.icon, 1024-point canvas).
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
    var almond: CGColor
    var rim: CGColor
    var finder: CGColor
    var blades: [CGColor] // link, wifi, product, travel, contact

    static let light = Appearance(
        tile: rgb(0xFFFFFF), almond: rgb(0xCFEAFA), rim: rgb(0xB3DAF2), finder: rgb(0x1C1C1E),
        blades: [rgb(0x1FA6E0), rgb(0x2FC25B), rgb(0xFF9500), rgb(0xFF2D55), rgb(0xA64FE0)]
    )
    static let dark = Appearance(
        tile: rgb(0x121216), almond: rgb(0x22303C), rim: rgb(0x3B4C5C), finder: rgb(0x0B0F14),
        blades: [rgb(0x64D2FF), rgb(0x30D158), rgb(0xFF9F0A), rgb(0xFF375F), rgb(0xBF5AF2)]
    )
}

func almond() -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: -420, y: 0))
    p.addCurve(to: CGPoint(x: 420, y: 0), control1: CGPoint(x: -231, y: -346.5), control2: CGPoint(x: 231, y: -346.5))
    p.addCurve(to: CGPoint(x: -420, y: 0), control1: CGPoint(x: 231, y: 346.5), control2: CGPoint(x: -231, y: 346.5))
    p.closeSubpath()
    return p
}

func blade(_ i: Int) -> CGPath {
    let th = (-90 + Double(i) * 72) * .pi / 180
    var t = CGAffineTransform(translationX: 118 * cos(th), y: 118 * sin(th)).rotated(by: th + 110 * .pi / 180)
    return CGPath(ellipseIn: CGRect(x: -138, y: -76, width: 276, height: 152), transform: &t)
}

func roundedSquare(_ side: CGFloat, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: -side / 2, y: -side / 2, width: side, height: side), cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// Draws the eye centred at the origin in 1024-point icon units.
func drawEye(_ ctx: CGContext, _ a: Appearance) {
    let lid = almond()
    ctx.addPath(lid)
    ctx.setFillColor(a.almond)
    ctx.fillPath()

    ctx.saveGState()
    ctx.addPath(lid)
    ctx.clip()

    // Blades: translucent, overlapping, one soft shadow for the group.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 8), blur: 22, color: rgb(0x000000, 0.16))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    for i in 0..<5 {
        ctx.addPath(blade(i))
        ctx.setFillColor(a.blades[i].copy(alpha: 0.86)!)
        ctx.fillPath()
    }
    ctx.endTransparencyLayer()
    ctx.restoreGState()
    for i in 0..<5 {
        ctx.addPath(blade(i))
        ctx.setStrokeColor(rgb(0xFFFFFF, 0.4))
        ctx.setLineWidth(4)
        ctx.strokePath()
    }

    // Pupil: white disc, finder pattern (7:5:3) even-odd filled.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 5), blur: 18, color: rgb(0x000000, 0.22))
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillEllipse(in: CGRect(x: -84, y: -84, width: 168, height: 168))
    ctx.restoreGState()
    let s: CGFloat = 106, module = s / 7, ro = s * 0.23
    ctx.addPath(roundedSquare(s, ro))
    ctx.addPath(roundedSquare(s - 2 * module, max(ro - module, 3)))
    ctx.addPath(roundedSquare(3 * module, ro * 0.4))
    ctx.setFillColor(a.finder)
    ctx.fillPath(using: .evenOdd)
    ctx.restoreGState()

    ctx.addPath(lid)
    ctx.setStrokeColor(a.rim)
    ctx.setLineWidth(12)
    ctx.strokePath()
}

/// A `side`×`side` tile with the eye. `eyeWidth` is the eye's share of the tile's width.
func render(side: Int, appearance: Appearance, rounded: Bool, eyeWidth: CGFloat) -> CGImage {
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
        let r = s * 0.225
        ctx.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s), cornerWidth: r, cornerHeight: r, transform: nil))
        ctx.fillPath()
    } else {
        ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))
    }

    let scale = s * eyeWidth / 840
    ctx.translateBy(x: s / 2, y: s / 2)
    ctx.scaleBy(x: scale, y: scale)
    drawEye(ctx, appearance)
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
    write(render(side: 29 * scale, appearance: .light, rounded: false, eyeWidth: 0.86), "icon\(suffix).png")
}
// logo.png: shown top-left of the pass next to logoText "Ojito". Max 160×50pt; we use a 50pt
// tile in the dark appearance so it reads on every pass colour.
for (scale, suffix) in [(1, ""), (2, "@2x"), (3, "@3x")] {
    write(render(side: 50 * scale, appearance: .dark, rounded: true, eyeWidth: 0.84), "logo\(suffix).png")
}
