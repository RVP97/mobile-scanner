import SwiftUI

/// The Ojito mark in full color: an almond eye whose iris is five translucent blades in the
/// kind colors, with a QR finder pattern for a pupil.
struct OjitoMark: View {
    var pose: Pose = .rest

    /// Everything the Welcome animation moves. `.rest` is the icon.
    struct Pose: Equatable {
        /// Per blade: 0 tucked behind the pupil, 1 in place.
        var blades: [Double] = Array(repeating: 1, count: OjitoGeometry.bladeCount)
        var pupil: Double = 1
        /// 1 open, 0 shut.
        var openness: Double = 1
        /// The whole iris turns by this much (the idle drift).
        var spin: Angle = .zero

        static let rest = Pose()
    }

    var body: some View {
        Canvas { context, size in
            OjitoRenderer.draw(pose, in: &context, size: size)
        }
        .aspectRatio(OjitoGeometry.aspectRatio, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private enum OjitoRenderer {
    static func draw(_ pose: OjitoMark.Pose, in context: inout GraphicsContext, size: CGSize) {
        let unit = OjitoGeometry.unit(fitting: size)
        context.translateBy(x: size.width / 2, y: size.height / 2)
        context.scaleBy(x: unit, y: unit)

        let lid = OjitoGeometry.almond(openness: max(0.015, pose.openness))
        context.fill(lid, with: .color(OjitoPalette.almond))

        context.drawLayer { iris in
            iris.clip(to: lid)
            drawBlades(pose, in: &iris)
            drawPupil(scale: pose.pupil, in: &iris)
        }
        context.stroke(lid, with: .color(OjitoPalette.rim), lineWidth: OjitoGeometry.rimWidth)
    }

    private static func drawBlades(_ pose: OjitoMark.Pose, in context: inout GraphicsContext) {
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.14), radius: 14, y: 8))
            for index in 0..<OjitoGeometry.bladeCount {
                let bloom = pose.blades.indices.contains(index) ? pose.blades[index] : 1
                guard bloom > 0 else { continue }
                let blade = OjitoGeometry.blade(index, bloom: bloom, spin: pose.spin)
                layer.opacity = min(1, bloom * 2)
                layer.fill(blade, with: .color(OjitoPalette.blades[index].opacity(0.86)))
            }
        }
        // Glass: a sheen on the upper half of each blade and a bright hairline edge.
        for index in 0..<OjitoGeometry.bladeCount {
            let bloom = pose.blades.indices.contains(index) ? pose.blades[index] : 1
            guard bloom > 0 else { continue }
            let blade = OjitoGeometry.blade(index, bloom: bloom, spin: pose.spin)
            let box = blade.boundingRect
            context.opacity = min(1, bloom * 2)
            context.fill(blade, with: .linearGradient(
                Gradient(colors: [.white.opacity(0.34), .white.opacity(0)]),
                startPoint: CGPoint(x: box.midX, y: box.minY),
                endPoint: CGPoint(x: box.midX, y: box.midY)
            ))
            context.stroke(blade, with: .color(.white.opacity(0.28)), lineWidth: 3)
        }
        context.opacity = 1
    }

    private static func drawPupil(scale: Double, in context: inout GraphicsContext) {
        guard scale > 0 else { return }
        let radius = OjitoGeometry.pupilRadius * scale
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.22), radius: 12, y: 5))
            layer.fill(Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)), with: .color(.white))
        }
        context.fill(
            OjitoGeometry.finder(size: OjitoGeometry.finderSize * scale),
            with: .color(OjitoPalette.finder),
            style: FillStyle(eoFill: true)
        )
    }
}

/// The mark as a single-color glyph for tiny or tinted places (Lock Screen widget, schematic
/// illustrations): eye outline, iris disc, finder pattern knocked out. Uses the foreground style.
struct OjitoGlyph: View {
    var body: some View {
        OjitoGlyphShape()
            .fill(style: FillStyle(eoFill: true))
            .aspectRatio(OjitoGeometry.aspectRatio, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

struct OjitoGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = OjitoGeometry.unit(fitting: rect.size)
        let outline = OjitoGeometry.almond().applying(CGAffineTransform(scaleX: 0.94, y: 0.94))
        let stroke: CGFloat = 60
        var glyph = outline.strokedPath(StrokeStyle(lineWidth: stroke, lineJoin: .round))
        let iris: CGFloat = 176
        glyph.addPath(Path(ellipseIn: CGRect(x: -iris, y: -iris, width: iris * 2, height: iris * 2)))
        glyph.addPath(OjitoGeometry.finder(size: 156))
        return glyph.applying(
            CGAffineTransform(translationX: rect.midX, y: rect.midY).scaledBy(x: unit, y: unit)
        )
    }
}

/// The app icon as a live vector view (Settings "About" and anywhere the tile is wanted).
struct OjitoAppIcon: View {
    var size: CGFloat = 120

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous)
        OjitoMark()
            .frame(width: size * OjitoGeometry.eyeSize.width / 1024)
            .frame(width: size, height: size)
            .background(OjitoPalette.tile, in: shape)
            .overlay { shape.strokeBorder(.separator, lineWidth: 0.5) }
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: "Ojito"))
            .accessibilityAddTraits(.isImage)
    }
}

#Preview("Mark") {
    VStack(spacing: 24) {
        OjitoMark().frame(width: 240)
        HStack(spacing: 24) {
            OjitoAppIcon(size: 120)
            OjitoAppIcon(size: 60)
            OjitoGlyph().foregroundStyle(.tint).frame(width: 44)
        }
    }
    .padding()
}
