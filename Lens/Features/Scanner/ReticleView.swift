import SwiftUI

/// Four rounded corner brackets. They rest in the center and spring onto a detected code, keeping
/// its perspective.
struct ReticleView: View {
    /// The code to hug; nil rests on `idle`.
    var quad: Quad?
    var idle: Quad
    var tint: Color = .white
    var lineWidth: CGFloat = 4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ReticleShape(quad: quad?.expanded(by: 10) ?? idle)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .shadow(color: .black.opacity(0.28), radius: 3, y: 1)
            .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.32, dampingFraction: 0.76), value: quad)
            .animation(.smooth(duration: 0.2), value: tint)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

nonisolated struct ReticleShape: Shape {
    var quad: Quad

    typealias CornerPair = AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData>

    var animatableData: AnimatablePair<CornerPair, CornerPair> {
        get {
            AnimatablePair(
                AnimatablePair(quad.topLeft.animatableData, quad.topRight.animatableData),
                AnimatablePair(quad.bottomRight.animatableData, quad.bottomLeft.animatableData)
            )
        }
        set {
            quad.topLeft.animatableData = newValue.first.first
            quad.topRight.animatableData = newValue.first.second
            quad.bottomRight.animatableData = newValue.second.first
            quad.bottomLeft.animatableData = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        quad.bracketPath(armLength: 30, cornerRadius: 12)
    }
}

/// Brief square where the user tapped to focus.
struct FocusMarkView: View {
    @State private var settled = false

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Palette.accent, lineWidth: 2)
            .frame(width: 72, height: 72)
            .scaleEffect(settled ? 1 : 1.35)
            .opacity(settled ? 1 : 0)
            .onAppear {
                withAnimation(.snappy(duration: 0.22)) { settled = true }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

#Preview("Reticle") {
    let size = CGSize(width: 390, height: 844)
    ZStack {
        Color.black
        ReticleView(
            quad: Quad(
                topLeft: CGPoint(x: 120, y: 260),
                topRight: CGPoint(x: 270, y: 250),
                bottomRight: CGPoint(x: 280, y: 400),
                bottomLeft: CGPoint(x: 110, y: 410)
            ),
            idle: .idle(in: size, bottomInset: 132),
            tint: CodeKind.link.tint
        )
    }
    .frame(width: size.width, height: size.height)
    .environment(\.colorScheme, .dark)
}
