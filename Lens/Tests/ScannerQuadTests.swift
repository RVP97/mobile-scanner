import CoreGraphics
import Testing
@testable import Lens

struct ScannerQuadTests {
    private func close(_ a: CGPoint, _ b: CGPoint, tolerance: CGFloat = 0.001) -> Bool {
        abs(a.x - b.x) < tolerance && abs(a.y - b.y) < tolerance
    }

    @Test func ordersCornersClockwiseFromTopLeftRegardlessOfInputOrder() throws {
        let tl = CGPoint(x: 10, y: 10), tr = CGPoint(x: 110, y: 12), br = CGPoint(x: 108, y: 115), bl = CGPoint(x: 8, y: 110)
        let shuffled = [br, tl, bl, tr]
        let quad = try #require(Quad(points: shuffled))
        #expect(quad.topLeft == tl)
        #expect(quad.topRight == tr)
        #expect(quad.bottomRight == br)
        #expect(quad.bottomLeft == bl)
    }

    @Test func counterClockwiseInputIsNormalized() throws {
        let rect = CGRect(x: 0, y: 0, width: 50, height: 50)
        let ccw = [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 50), CGPoint(x: 50, y: 50), CGPoint(x: 50, y: 0)]
        #expect(Quad(points: ccw) == Quad(rect: rect))
    }

    @Test func rejectsTooFewPoints() {
        #expect(Quad(points: [.zero, CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 0)]) == nil)
    }

    @Test func areaCenterAndBoundingBox() {
        let quad = Quad(rect: CGRect(x: 20, y: 40, width: 100, height: 50))
        #expect(quad.area == 5000)
        #expect(quad.center == CGPoint(x: 70, y: 65))
        #expect(quad.boundingBox == CGRect(x: 20, y: 40, width: 100, height: 50))
    }

    @Test func expandingMovesEdgesOutward() {
        let quad = Quad(rect: CGRect(x: 0, y: 0, width: 100, height: 100)).expanded(by: 10)
        #expect(close(quad.topLeft, CGPoint(x: -10, y: -10)))
        #expect(close(quad.bottomRight, CGPoint(x: 110, y: 110)))
    }

    @Test func interpolationHitsBothEnds() {
        let a = Quad(rect: CGRect(x: 0, y: 0, width: 10, height: 10))
        let b = Quad(rect: CGRect(x: 100, y: 100, width: 50, height: 50))
        #expect(a.interpolated(to: b, fraction: 0) == a)
        #expect(a.interpolated(to: b, fraction: 1) == b)
        #expect(a.interpolated(to: b, fraction: 0.5).topLeft == CGPoint(x: 50, y: 50))
    }

    @Test func idleReticleIsCenteredAboveTheSheet() {
        let idle = Quad.idle(in: CGSize(width: 390, height: 844), bottomInset: 132)
        let box = idle.boundingBox
        #expect(abs(box.midX - 195) < 0.001)
        #expect(abs(box.midY - (844 - 132) / 2) < 0.001)
        #expect(box.width == box.height)
        #expect(box.width <= 264)
    }

    @Test func homographyMapsSourceCornersOntoQuad() {
        let size = CGSize(width: 120, height: 120)
        let quad = Quad(
            topLeft: CGPoint(x: 100, y: 200),
            topRight: CGPoint(x: 260, y: 180),
            bottomRight: CGPoint(x: 280, y: 360),
            bottomLeft: CGPoint(x: 90, y: 330)
        )
        let h = Homography(mapping: size, onto: quad)
        #expect(close(h.apply(to: .zero), quad.topLeft))
        #expect(close(h.apply(to: CGPoint(x: 120, y: 0)), quad.topRight))
        #expect(close(h.apply(to: CGPoint(x: 120, y: 120)), quad.bottomRight))
        #expect(close(h.apply(to: CGPoint(x: 0, y: 120)), quad.bottomLeft))
    }

    @Test func homographyOfARectangleIsAffine() {
        let h = Homography(mapping: CGSize(width: 10, height: 10), onto: Quad(rect: CGRect(x: 5, y: 5, width: 20, height: 40)))
        #expect(h.m13 == 0 && h.m23 == 0)
        #expect(close(h.apply(to: CGPoint(x: 5, y: 5)), CGPoint(x: 15, y: 25)))
    }

    @Test func bracketsDrawFourArmsAndSkipDegenerateQuads() {
        let path = Quad(rect: CGRect(x: 0, y: 0, width: 200, height: 200)).bracketPath()
        #expect(!path.isEmpty)
        #expect(path.boundingRect.insetBy(dx: -0.5, dy: -0.5).contains(CGRect(x: 0, y: 0, width: 200, height: 200)))
        let degenerate = Quad(rect: CGRect(x: 10, y: 10, width: 0, height: 0)).bracketPath()
        #expect(degenerate.isEmpty)
    }
}
