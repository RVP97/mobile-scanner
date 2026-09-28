import CoreGraphics
import SwiftUI

/// The four corners of a detected code on screen, ordered clockwise from the corner nearest the top-left.
nonisolated struct Quad: Hashable, Sendable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    init(topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    init(rect: CGRect) {
        self.init(
            topLeft: CGPoint(x: rect.minX, y: rect.minY),
            topRight: CGPoint(x: rect.maxX, y: rect.minY),
            bottomRight: CGPoint(x: rect.maxX, y: rect.maxY),
            bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
        )
    }

    /// Orders arbitrary corner points (as AVFoundation or Vision report them, in any rotation) so that
    /// animating between two quads never twists: clockwise in screen space (y down), starting at the
    /// corner with the smallest x + y.
    init?(points: [CGPoint]) {
        guard points.count >= 4 else { return nil }
        let corners = Array(points.prefix(4))
        let center = CGPoint(
            x: corners.map(\.x).reduce(0, +) / 4,
            y: corners.map(\.y).reduce(0, +) / 4
        )
        let clockwise = corners.sorted {
            atan2($0.y - center.y, $0.x - center.x) < atan2($1.y - center.y, $1.x - center.x)
        }
        guard let start = clockwise.indices.min(by: {
            clockwise[$0].x + clockwise[$0].y < clockwise[$1].x + clockwise[$1].y
        }) else { return nil }
        let ordered = (0..<4).map { clockwise[(start + $0) % 4] }
        self.init(topLeft: ordered[0], topRight: ordered[1], bottomRight: ordered[2], bottomLeft: ordered[3])
    }

    var corners: [CGPoint] { [topLeft, topRight, bottomRight, bottomLeft] }

    var center: CGPoint {
        CGPoint(
            x: (topLeft.x + topRight.x + bottomRight.x + bottomLeft.x) / 4,
            y: (topLeft.y + topRight.y + bottomRight.y + bottomLeft.y) / 4
        )
    }

    var boundingBox: CGRect {
        let xs = corners.map(\.x), ys = corners.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return .null }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Enclosed area (shoelace formula). Used to pick the most prominent code in a frame.
    var area: CGFloat {
        let p = corners
        var sum: CGFloat = 0
        for i in 0..<4 {
            let a = p[i], b = p[(i + 1) % 4]
            sum += a.x * b.y - b.x * a.y
        }
        return abs(sum) / 2
    }

    /// Pushes every corner away from the center so each edge moves out by roughly `distance`.
    func expanded(by distance: CGFloat) -> Quad {
        let c = center
        func push(_ p: CGPoint) -> CGPoint {
            let dx = p.x - c.x, dy = p.y - c.y
            let length = max(hypot(dx, dy), .ulpOfOne)
            let step = distance * 2.squareRoot()
            return CGPoint(x: p.x + dx / length * step, y: p.y + dy / length * step)
        }
        return Quad(topLeft: push(topLeft), topRight: push(topRight), bottomRight: push(bottomRight), bottomLeft: push(bottomLeft))
    }

    func interpolated(to other: Quad, fraction t: CGFloat) -> Quad {
        func lerp(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
        return Quad(
            topLeft: lerp(topLeft, other.topLeft),
            topRight: lerp(topRight, other.topRight),
            bottomRight: lerp(bottomRight, other.bottomRight),
            bottomLeft: lerp(bottomLeft, other.bottomLeft)
        )
    }

    /// The resting reticle: a centered square in the part of the screen the sheet doesn't cover.
    static func idle(in size: CGSize, bottomInset: CGFloat) -> Quad {
        let usableHeight = max(size.height - bottomInset, 0)
        let side = min(min(size.width, usableHeight) * 0.62, 264)
        let center = CGPoint(x: size.width / 2, y: usableHeight / 2)
        return Quad(rect: CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side))
    }
}

// MARK: - Brackets

extension Quad {
    /// Four rounded corner brackets hugging the quad. Arms follow the quad's edges, so the brackets
    /// keep the code's perspective.
    nonisolated func bracketPath(armLength: CGFloat = 30, cornerRadius: CGFloat = 12) -> Path {
        var path = Path()
        let p = corners
        for i in 0..<4 {
            let corner = p[i], previous = p[(i + 3) % 4], next = p[(i + 1) % 4]
            let toPrevious = distance(corner, previous), toNext = distance(corner, next)
            let arm = min(armLength, toPrevious * 0.34, toNext * 0.34)
            guard arm > 1 else { continue }
            let start = point(from: corner, toward: previous, length: arm)
            let end = point(from: corner, toward: next, length: arm)
            path.move(to: start)
            path.addArc(tangent1End: corner, tangent2End: end, radius: min(cornerRadius, arm * 0.6))
            path.addLine(to: end)
        }
        return path
    }

    private nonisolated func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(b.x - a.x, b.y - a.y) }

    private nonisolated func point(from a: CGPoint, toward b: CGPoint, length: CGFloat) -> CGPoint {
        let d = max(distance(a, b), .ulpOfOne)
        return CGPoint(x: a.x + (b.x - a.x) / d * length, y: a.y + (b.y - a.y) / d * length)
    }
}

// MARK: - Perspective

/// A plane-to-plane projective mapping (row-vector convention, like `ProjectionTransform`):
/// `x' = (m11·x + m21·y + m31) / w`, `y' = (m12·x + m22·y + m32) / w`, `w = m13·x + m23·y + m33`.
nonisolated struct Homography: Hashable, Sendable {
    var m11: CGFloat, m12: CGFloat, m13: CGFloat
    var m21: CGFloat, m22: CGFloat, m23: CGFloat
    var m31: CGFloat, m32: CGFloat, m33: CGFloat

    /// Maps the rectangle `(0, 0, size)` onto `quad`, top-left to top-left (Heckbert's square-to-quad).
    init(mapping size: CGSize, onto quad: Quad) {
        let x0 = quad.topLeft.x, y0 = quad.topLeft.y
        let x1 = quad.topRight.x, y1 = quad.topRight.y
        let x2 = quad.bottomRight.x, y2 = quad.bottomRight.y
        let x3 = quad.bottomLeft.x, y3 = quad.bottomLeft.y

        let dx1 = x1 - x2, dx2 = x3 - x2, dx3 = x0 - x1 + x2 - x3
        let dy1 = y1 - y2, dy2 = y3 - y2, dy3 = y0 - y1 + y2 - y3

        var g: CGFloat = 0, h: CGFloat = 0
        let denominator = dx1 * dy2 - dx2 * dy1
        if abs(dx3) > 1e-9 || abs(dy3) > 1e-9, abs(denominator) > 1e-9 {
            g = (dx3 * dy2 - dx2 * dy3) / denominator
            h = (dx1 * dy3 - dx3 * dy1) / denominator
        }
        let a = x1 - x0 + g * x1, b = x3 - x0 + h * x3
        let d = y1 - y0 + g * y1, e = y3 - y0 + h * y3

        // Pre-scale so the source is `size` rather than the unit square.
        let sx = size.width > 0 ? 1 / size.width : 0
        let sy = size.height > 0 ? 1 / size.height : 0
        m11 = a * sx; m12 = d * sx; m13 = g * sx
        m21 = b * sy; m22 = e * sy; m23 = h * sy
        m31 = x0; m32 = y0; m33 = 1
    }

    func apply(to point: CGPoint) -> CGPoint {
        let w = m13 * point.x + m23 * point.y + m33
        guard abs(w) > .ulpOfOne else { return point }
        return CGPoint(
            x: (m11 * point.x + m21 * point.y + m31) / w,
            y: (m12 * point.x + m22 * point.y + m32) / w
        )
    }

    var projectionTransform: ProjectionTransform {
        var t = ProjectionTransform()
        t.m11 = m11; t.m12 = m12; t.m13 = m13
        t.m21 = m21; t.m22 = m22; t.m23 = m23
        t.m31 = m31; t.m32 = m32; t.m33 = m33
        return t
    }
}
