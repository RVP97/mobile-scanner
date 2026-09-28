import SwiftUI

/// The Ojito eye, in the app icon's 1024-point units (Resources/AppIcon.icon draws the same
/// shapes) with the origin moved to the centre of the eye.
nonisolated enum OjitoGeometry {
    /// Bounding box of the almond at full openness.
    static let eyeSize = CGSize(width: 840, height: 520)
    static let aspectRatio = eyeSize.width / eyeSize.height
    static let bladeCount = 5
    static let bladeDistance: CGFloat = 118
    static let bladeRadii = CGSize(width: 138, height: 76)
    static let pupilRadius: CGFloat = 84
    static let finderSize: CGFloat = 106

    /// Scale from icon units to a frame of `size`, keeping the eye's proportions.
    /// Leaves room for the rim stroke, which straddles the almond's edge.
    static func unit(fitting size: CGSize) -> CGFloat {
        let margin = rimWidth
        return min(size.width / (eyeSize.width + margin), size.height / (eyeSize.height + margin))
    }

    static let rimWidth: CGFloat = 12

    /// The almond outline. `openness` squashes the lids toward the centre line (a blink).
    static func almond(openness: CGFloat = 1) -> Path {
        let halfWidth = eyeSize.width / 2
        let handleX: CGFloat = 231
        let handleY: CGFloat = 346.5 * openness
        var path = Path()
        path.move(to: CGPoint(x: -halfWidth, y: 0))
        path.addCurve(
            to: CGPoint(x: halfWidth, y: 0),
            control1: CGPoint(x: -handleX, y: -handleY),
            control2: CGPoint(x: handleX, y: -handleY)
        )
        path.addCurve(
            to: CGPoint(x: -halfWidth, y: 0),
            control1: CGPoint(x: handleX, y: handleY),
            control2: CGPoint(x: -handleX, y: handleY)
        )
        path.closeSubpath()
        return path
    }

    /// One iris blade. At `bloom` 0 it's small and tucked behind the pupil, turned back
    /// against the swirl; at 1 it sits exactly where the icon has it.
    static func blade(_ index: Int, bloom: CGFloat, spin: Angle) -> Path {
        let direction = Angle.degrees(-90 + Double(index) * 72) + spin - .degrees(150 * (1 - bloom))
        let distance = bladeDistance * bloom
        let scale = 0.3 + 0.7 * bloom
        let radii = bladeRadii
        let ellipse = Path(ellipseIn: CGRect(x: -radii.width, y: -radii.height, width: radii.width * 2, height: radii.height * 2))
        let placement = CGAffineTransform(
            translationX: distance * cos(direction.radians),
            y: distance * sin(direction.radians)
        )
        .rotated(by: (direction + .degrees(110)).radians)
        .scaledBy(x: scale, y: scale)
        return ellipse.applying(placement)
    }

    /// A QR finder pattern (7:5:3), for an even-odd fill: dark ring, light gap, dark core.
    static func finder(size: CGFloat) -> Path {
        let module = size / 7
        let outerRadius = size * 0.23
        let innerRadius = max(outerRadius - module, size * 0.03)
        let outer = CGRect(x: -size / 2, y: -size / 2, width: size, height: size)
        var path = Path(roundedRect: outer, cornerRadius: outerRadius, style: .continuous)
        path.addPath(Path(roundedRect: outer.insetBy(dx: module, dy: module), cornerRadius: innerRadius, style: .continuous))
        path.addPath(Path(roundedRect: outer.insetBy(dx: module * 2, dy: module * 2), cornerRadius: outerRadius * 0.4, style: .continuous))
        return path
    }
}

/// Brand colors of the mark: the icon's own vivid kind colors (link, Wi-Fi, product, travel,
/// contact), which are brighter than the text-safe `Palette` tints.
nonisolated enum OjitoPalette {
    static let blades: [Color] = [
        Color(light: 0x1FA6E0, dark: 0x64D2FF),
        Color(light: 0x2FC25B, dark: 0x30D158),
        Color(light: 0xFF9500, dark: 0xFF9F0A),
        Color(light: 0xFF2D55, dark: 0xFF375F),
        Color(light: 0xA64FE0, dark: 0xBF5AF2),
    ]
    static let almond = Color(light: 0xCFEAFA, dark: 0x22303C)
    static let rim = Color(light: 0xB3DAF2, dark: 0x3B4C5C)
    static let finder = Color(light: 0x1C1C1E, dark: 0x0B0F14)
    static let tile = Color(light: 0xFFFFFF, dark: 0x121216)
}
