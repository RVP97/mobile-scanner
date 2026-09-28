import SwiftUI

// The Lens mark: four rounded viewfinder brackets around a lens. Same geometry as the
// app icon (Resources/AppIcon.icon), which draws it on a 1024-point canvas.
private nonisolated enum MarkGeometry {
    /// Width of the whole glyph, stroke included, in icon-canvas points.
    static let extent: CGFloat = 604
    static let halfBox: CGFloat = 268
    static let arm: CGFloat = 176
    static let cornerRadius: CGFloat = 96
    static let stroke: CGFloat = 68
    static let pupilDiameter: CGFloat = 208
}

/// The four brackets, filled. Scales to the smaller side of its frame.
struct ViewfinderBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / MarkGeometry.extent
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let half = MarkGeometry.halfBox * unit
        let arm = MarkGeometry.arm * unit
        let radius = MarkGeometry.cornerRadius * unit

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
        return brackets.strokedPath(StrokeStyle(lineWidth: MarkGeometry.stroke * unit, lineCap: .round, lineJoin: .round))
    }
}

/// The glyph alone, drawn in the current foreground style.
struct LensMark: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                ViewfinderBrackets()
                Circle()
                    .frame(width: side * MarkGeometry.pupilDiameter / MarkGeometry.extent)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The app icon as a live vector view (onboarding hero, Settings "About").
struct LensAppIcon: View {
    var size: CGFloat = 120

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [Self.backgroundTop, Self.backgroundBottom], startPoint: .top, endPoint: .bottom))
            shape.strokeBorder(
                LinearGradient(colors: [.white.opacity(0.42), .white.opacity(0.04), .white.opacity(0.12)], startPoint: .top, endPoint: .bottom),
                lineWidth: max(1, size / 110)
            )
            ZStack {
                ViewfinderBrackets().fill(Self.glyph)
                Circle()
                    .fill(Self.pupil)
                    .frame(width: size * MarkGeometry.pupilDiameter / 1024)
                    .shadow(color: .black.opacity(0.18), radius: size / 60, y: size / 90)
            }
            .frame(width: size * MarkGeometry.extent / 1024, height: size * MarkGeometry.extent / 1024)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(Text("Lens"))
        .accessibilityAddTraits(.isImage)
    }

    private static let backgroundTop = Color(light: 0x3DC4F5, dark: 0x1E3A48)
    private static let backgroundBottom = Color(light: 0x0467A6, dark: 0x05090C)
    private static let glyph = Color(light: 0xFFFFFF, dark: 0x45C9FF)
    private static let pupil = LinearGradient(
        colors: [Color(light: 0xFFFFFF, dark: 0xE2F8FF), Color(light: 0xEAF7FD, dark: 0x1591CF)],
        startPoint: .top,
        endPoint: .bottom
    )
}

#Preview("Mark") {
    HStack(spacing: 24) {
        LensAppIcon(size: 120)
        LensAppIcon(size: 60)
        LensMark().foregroundStyle(.tint).frame(width: 44)
    }
    .padding()
}
