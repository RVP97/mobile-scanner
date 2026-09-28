import SwiftUI

/// Four rounded viewfinder brackets, filled. Scales to the smaller side of its frame.
struct ViewfinderBrackets: Shape {
    /// Proportions on a 604-point box, stroke included.
    private static let extent: CGFloat = 604
    private static let halfBox: CGFloat = 268
    private static let arm: CGFloat = 176
    private static let cornerRadius: CGFloat = 96
    private static let stroke: CGFloat = 68

    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / Self.extent
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let half = Self.halfBox * unit
        let arm = Self.arm * unit
        let radius = Self.cornerRadius * unit

        var corner = Path()
        let origin = CGPoint(x: center.x - half, y: center.y - half)
        corner.move(to: CGPoint(x: origin.x, y: origin.y + arm))
        corner.addArc(
            tangent1End: origin,
            tangent2End: CGPoint(x: origin.x + radius, y: origin.y),
            radius: radius
        )
        corner.addLine(to: CGPoint(x: origin.x + arm, y: origin.y))

        var brackets = Path()
        for quarter in 0..<4 {
            let turn = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: CGFloat(quarter) * .pi / 2)
                .translatedBy(x: -center.x, y: -center.y)
            brackets.addPath(corner.applying(turn))
        }
        return brackets.strokedPath(StrokeStyle(lineWidth: Self.stroke * unit, lineCap: .round, lineJoin: .round))
    }
}
