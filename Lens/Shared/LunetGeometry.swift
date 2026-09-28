import SwiftUI

/// The Lunet loupe, in the app icon's 1024-point units (Resources/AppIcon.icon draws the same
/// shapes): a thick glass lens resting on a small QR code, magnifying its top-left finder.
nonisolated enum LunetGeometry {
    /// The square of icon space the mark occupies: centred on the QR code, like the icon, and
    /// wide enough for the lens reaching out toward the top-left (the artwork spans 149...778).
    static let bounds = CGRect(x: 144, y: 144, width: 736, height: 736)

    // MARK: The code

    static let module: CGFloat = 24
    static let modulePitch: CGFloat = 28
    static let moduleRadius: CGFloat = 7.2
    static let finderSize: CGFloat = 196
    /// Top-left corners of the three finders. The first hides under the lens at rest.
    static let finderOrigins: [CGPoint] = [
        CGPoint(x: 246, y: 246),
        CGPoint(x: 582, y: 246),
        CGPoint(x: 246, y: 582),
    ]
    /// Data modules as (column, row) on the 28-point grid starting at `moduleOrigin`.
    static let moduleOrigin: CGFloat = 472
    static let modules: [(Int, Int)] = [
        (6, 0), (9, 0),
        (3, 1), (5, 1), (10, 1),
        (5, 2), (6, 2), (8, 2), (10, 2),
        (1, 3), (3, 3), (4, 3), (5, 3), (7, 3),
        (2, 4), (3, 4), (4, 4), (7, 4), (8, 4), (9, 4), (10, 4),
        (2, 5), (3, 5), (4, 5), (5, 5),
        (1, 6), (6, 6), (7, 6), (8, 6), (10, 6),
        (0, 7), (1, 7), (2, 7), (3, 7), (4, 7), (5, 7), (6, 7), (7, 7), (8, 7), (9, 7),
        (1, 8), (2, 8), (3, 8), (4, 8), (5, 8), (10, 8),
        (0, 9), (1, 9), (2, 9), (4, 9), (5, 9), (8, 9), (10, 9),
        (4, 10), (5, 10), (6, 10), (10, 10),
    ]

    /// A QR finder (7:5:3) of `size` with its top-left at `origin`, for an even-odd fill.
    static func finder(size: CGFloat = finderSize, at origin: CGPoint) -> Path {
        let ring = size / 7
        let outer = CGRect(origin: origin, size: CGSize(width: size, height: size))
        var path = Path(roundedRect: outer, cornerRadius: size * 0.2286, style: .circular)
        path.addPath(Path(roundedRect: outer.insetBy(dx: ring, dy: ring), cornerRadius: size * 0.0857, style: .circular))
        path.addPath(Path(roundedRect: outer.insetBy(dx: ring * 2, dy: ring * 2), cornerRadius: size * 0.0913, style: .circular))
        return path
    }

    static var dataModules: Path {
        var path = Path()
        for (column, row) in modules {
            let rect = CGRect(
                x: moduleOrigin + CGFloat(column) * modulePitch,
                y: moduleOrigin + CGFloat(row) * modulePitch,
                width: module, height: module
            )
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: moduleRadius, height: moduleRadius))
        }
        return path
    }

    // MARK: The loupe

    /// Centre of the lens (the disc) at rest.
    static let lensCenter = CGPoint(x: 370, y: 370)
    static let discRadius: CGFloat = 178
    static let rimOuterRadius: CGFloat = 214
    static let rimInnerRadius: CGFloat = 172
    /// Each rim's offset from the lens centre: the chromatic fringe (link, travel, Wi-Fi colors),
    /// drawn top to bottom in this order.
    static let rimOffsets: [CGVector] = [
        CGVector(dx: -7, dy: -7),
        CGVector(dx: 9, dy: 2),
        CGVector(dx: 1, dy: 10),
    ]
    /// How much the lens magnifies, and the point it magnifies about relative to its centre.
    /// Chosen so the hidden top-left finder lands exactly on the icon's big finder.
    static let magnification: CGFloat = 240 / 196
    static let magnifierAnchor = CGVector(dx: -159.5, dy: -159.5)

    static func ring(center: CGPoint) -> Path {
        var path = circle(center: center, radius: rimOuterRadius)
        path.addPath(circle(center: center, radius: rimInnerRadius))
        return path
    }

    static func circle(center: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    /// The four-point sparkle on the lens, centred on `center`.
    static let glintCenter = CGPoint(x: 270, y: 266)
    static func glint(center: CGPoint = glintCenter, radius: CGFloat = 54) -> Path {
        let pinch = radius * 0.22
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - radius))
        path.addQuadCurve(to: CGPoint(x: center.x + radius, y: center.y), control: CGPoint(x: center.x + pinch, y: center.y - pinch))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y + radius), control: CGPoint(x: center.x + pinch, y: center.y + pinch))
        path.addQuadCurve(to: CGPoint(x: center.x - radius, y: center.y), control: CGPoint(x: center.x - pinch, y: center.y + pinch))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius), control: CGPoint(x: center.x - pinch, y: center.y - pinch))
        path.closeSubpath()
        return path
    }

    /// The glyph drops the optical centring: at 16 points it should fill its frame.
    static let glyphBounds = CGRect(x: 140, y: 140, width: 648, height: 648)

    /// Transform from icon units to a view of `size`, centring `frame` (icon units).
    static func transform(fitting size: CGSize, frame: CGRect = bounds) -> CGAffineTransform {
        let scale = min(size.width, size.height) / frame.width
        return CGAffineTransform(translationX: size.width / 2, y: size.height / 2)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -frame.midX, y: -frame.midY)
    }
}

/// Brand colors of the mark, straight from the icon's layers.
nonisolated enum LunetPalette {
    static let rims: [Color] = [
        Color(light: 0x1FA6E0, dark: 0x64D2FF),
        Color(light: 0xFF2D55, dark: 0xFF375F),
        Color(light: 0x2FC25B, dark: 0x30D158),
    ]
    static let code = Color(light: 0xBFC4CB, dark: 0x434952)
    static let disc = Color(light: 0xE8F7FF, dark: 0x15232E)
    static let finder = Color(light: 0x1C1C1E, dark: 0xFFFFFF)
    static let tile = Color(light: 0xFFFFFF, dark: 0x0E1116)
}
