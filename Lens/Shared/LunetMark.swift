import SwiftUI

/// The Lunet mark in full color: a thick glass loupe with a cyan/pink/green refraction rim and
/// a sparkle, resting on a small QR code and magnifying its top-left finder.
struct LunetMark: View {
    var pose: Pose = .rest

    /// Everything the Welcome animation moves. `.rest` is the icon.
    struct Pose: Equatable {
        /// How visible the code under the lens is (0...1).
        var code: Double = 1
        /// The lens's offset from its resting place, in icon units.
        var lensOffset: CGSize = .zero
        var lensOpacity: Double = 1
        /// 0 blurry and soft, 1 the crisp magnified finder; may overshoot a little (the snap).
        var focus: Double = 1
        /// The chromatic fringe's direction around the rim; one full turn is the sweep.
        var refraction: Angle = .zero
        /// How far apart the rim colors spread (1 is the icon).
        var spread: Double = 1
        /// The sparkle's size (0 hidden, 1 the icon) and turn.
        var glint: Double = 1
        var glintSpin: Angle = .zero

        static let rest = Pose()
    }

    var body: some View {
        Canvas { context, size in
            LunetRenderer.draw(pose, in: &context, size: size)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private enum LunetRenderer {
    static func draw(_ pose: LunetMark.Pose, in context: inout GraphicsContext, size: CGSize) {
        context.concatenate(LunetGeometry.transform(fitting: size))
        let center = CGPoint(
            x: LunetGeometry.lensCenter.x + pose.lensOffset.width,
            y: LunetGeometry.lensCenter.y + pose.lensOffset.height
        )

        context.drawLayer { code in
            code.opacity = pose.code
            drawCode(in: &code)
        }

        context.drawLayer { lens in
            lens.opacity = pose.lensOpacity
            drawLens(pose, center: center, in: &lens)
        }
    }

    /// The code as it lies on the table: three finders and the data modules.
    /// `ink` resolves the hidden top-left finder from the code's grey to the icon's ink.
    private static func drawCode(in context: inout GraphicsContext, ink: Double = 0) {
        let fill = FillStyle(eoFill: true)
        for origin in LunetGeometry.finderOrigins {
            context.fill(LunetGeometry.finder(at: origin), with: .color(LunetPalette.code), style: fill)
        }
        if ink > 0, let hidden = LunetGeometry.finderOrigins.first {
            context.fill(LunetGeometry.finder(at: hidden), with: .color(LunetPalette.finder.opacity(ink)), style: fill)
        }
        context.fill(LunetGeometry.dataModules, with: .color(LunetPalette.code))
    }

    private static func drawLens(_ pose: LunetMark.Pose, center: CGPoint, in context: inout GraphicsContext) {
        let disc = LunetGeometry.circle(center: center, radius: LunetGeometry.discRadius)

        // A soft cyan halo lifts the glass off the code.
        context.drawLayer { glow in
            glow.addFilter(.shadow(color: LunetPalette.rims[0].opacity(0.35), radius: 22, y: 6))
            glow.fill(disc, with: .color(LunetPalette.disc))
        }

        // What the lens sees: the code, magnified about a point that travels with it.
        context.drawLayer { view in
            view.clip(to: disc)
            let anchor = CGPoint(
                x: center.x + LunetGeometry.magnifierAnchor.dx,
                y: center.y + LunetGeometry.magnifierAnchor.dy
            )
            let focus = max(0, pose.focus)
            let scale = LunetGeometry.magnification * (0.92 + 0.08 * focus)
            view.translateBy(x: anchor.x, y: anchor.y)
            view.scaleBy(x: scale, y: scale)
            view.translateBy(x: -anchor.x, y: -anchor.y)
            let blur = 9 * (1 - min(1, focus))
            if blur > 0.05 { view.addFilter(.blur(radius: blur)) }
            drawCode(in: &view, ink: min(1, focus))
        }

        drawRims(pose, center: center, in: &context)
        drawGlint(pose, lensOffset: pose.lensOffset, in: &context)
    }

    private static func drawRims(_ pose: LunetMark.Pose, center: CGPoint, in context: inout GraphicsContext) {
        context.drawLayer { rims in
            rims.addFilter(.shadow(color: .black.opacity(0.12), radius: 10, y: 6))
            // Bottom to top: green, pink, then the cyan rim.
            for index in LunetGeometry.rimOffsets.indices.reversed() {
                let offset = rotated(LunetGeometry.rimOffsets[index], by: pose.refraction, scale: pose.spread)
                let ring = LunetGeometry.ring(center: CGPoint(x: center.x + offset.dx, y: center.y + offset.dy))
                rims.fill(ring, with: .color(LunetPalette.rims[index]), style: FillStyle(eoFill: true))
                if index == 0 { drawSheen(on: ring, center: center, in: &rims) }
            }
        }
    }

    /// Glass: a bright top-left highlight and a hairline on the cyan rim.
    private static func drawSheen(on ring: Path, center: CGPoint, in context: inout GraphicsContext) {
        let reach = LunetGeometry.rimOuterRadius
        context.fill(ring, with: .linearGradient(
            Gradient(colors: [.white.opacity(0.45), .white.opacity(0), .white.opacity(0)]),
            startPoint: CGPoint(x: center.x - reach, y: center.y - reach),
            endPoint: CGPoint(x: center.x + reach * 0.4, y: center.y + reach * 0.4)
        ), style: FillStyle(eoFill: true))
        context.stroke(ring, with: .color(.white.opacity(0.3)), lineWidth: 2.5)
    }

    private static func drawGlint(_ pose: LunetMark.Pose, lensOffset: CGSize, in context: inout GraphicsContext) {
        guard pose.glint > 0.01 else { return }
        let center = CGPoint(
            x: LunetGeometry.glintCenter.x + lensOffset.width,
            y: LunetGeometry.glintCenter.y + lensOffset.height
        )
        let star = LunetGeometry.glint(center: .zero, radius: 54 * pose.glint)
            .applying(CGAffineTransform(rotationAngle: pose.glintSpin.radians))
            .applying(CGAffineTransform(translationX: center.x, y: center.y))
        context.drawLayer { glint in
            glint.addFilter(.shadow(color: .black.opacity(0.22), radius: 6, y: 2))
            glint.fill(star, with: .color(.white))
        }
    }

    private static func rotated(_ vector: CGVector, by angle: Angle, scale: Double) -> CGVector {
        let c = cos(angle.radians), s = sin(angle.radians)
        return CGVector(dx: (vector.dx * c - vector.dy * s) * scale, dy: (vector.dx * s + vector.dy * c) * scale)
    }
}

/// The mark as a single-color glyph for tiny or tinted places (Lock Screen widget, controls,
/// schematic illustrations): the lens ring with its finder, over the code's other two finders
/// and a few coarse modules. Uses the foreground style.
struct LunetGlyph: View {
    var body: some View {
        LunetGlyphShape()
            .fill(style: FillStyle(eoFill: true))
            .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

struct LunetGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = LunetGeometry.lensCenter
        var glyph = LunetGeometry.circle(center: center, radius: 222)
        glyph.addPath(LunetGeometry.circle(center: center, radius: 162))
        glyph.addPath(LunetGeometry.finder(size: 212, at: CGPoint(x: center.x - 106, y: center.y - 106)))
        // The code's other finders, simplified so they hold up at 16 points.
        for origin in LunetGeometry.finderOrigins.dropFirst() {
            glyph.addPath(LunetGeometry.finder(at: origin))
        }
        for (x, y) in [(610, 610), (610, 694), (694, 694)] {
            glyph.addRoundedRect(in: CGRect(x: x, y: y, width: 64, height: 64), cornerSize: CGSize(width: 16, height: 16))
        }
        return glyph.applying(LunetGeometry.transform(fitting: rect.size, frame: LunetGeometry.glyphBounds).concatenating(
            CGAffineTransform(translationX: rect.minX, y: rect.minY)
        ))
    }
}

/// The app icon as a live vector view (Settings "About" and anywhere the tile is wanted).
struct LunetAppIcon: View {
    var size: CGFloat = 120

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous)
        let markSide = size * LunetGeometry.bounds.width / 1024
        LunetMark()
            .frame(width: markSide, height: markSide)
            .offset(
                x: size * (LunetGeometry.bounds.midX - 512) / 1024,
                y: size * (LunetGeometry.bounds.midY - 512) / 1024
            )
            .frame(width: size, height: size)
            .background(LunetPalette.tile, in: shape)
            .overlay { shape.strokeBorder(.separator, lineWidth: 0.5) }
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: "Lunet"))
            .accessibilityAddTraits(.isImage)
    }
}

#Preview("Mark") {
    VStack(spacing: 24) {
        LunetMark().frame(width: 240)
        HStack(spacing: 24) {
            LunetAppIcon(size: 120)
            LunetAppIcon(size: 60)
            LunetGlyph().foregroundStyle(.tint).frame(width: 44)
        }
    }
    .padding()
}
