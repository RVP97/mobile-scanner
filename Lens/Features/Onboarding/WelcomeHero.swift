import SwiftUI

/// The one choreographed moment: a QR code dissolves from its center outward, the Lens mark
/// forms where it was, and the kinds of answers it can give fan out around it.
struct WelcomeHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Pref.haptics) private var haptics = Pref.Default.haptics
    @State private var start: Date?
    @State private var landed = false

    private static let kinds: [CodeKind] = [.link, .wifi, .product, .travel, .contact, .text]
    private static let matrix = QRMatrix("https://lens.app/welcome")
    private static let duration: TimeInterval = 2.3
    private static let tile: CGFloat = 52

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(paused: start == nil || landed)) { timeline in
                let t = elapsed(at: timeline.date)
                scene(in: proxy.size, t: t)
            }
        }
        .frame(height: 280)
        .accessibilityHidden(true)
        .sensoryFeedback(.impact(weight: .light), trigger: landed) { _, didLand in
            didLand && haptics && !reduceMotion
        }
        .task {
            guard !reduceMotion else {
                landed = true
                return
            }
            start = .now
            try? await Task.sleep(for: .seconds(Self.duration))
            landed = true
        }
    }

    private func elapsed(at date: Date) -> Double {
        if landed || reduceMotion { return Self.duration }
        guard let start else { return 0 }
        return date.timeIntervalSince(start)
    }

    @ViewBuilder
    private func scene(in size: CGSize, t: Double) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radiusX = min(144, (size.width - Self.tile) / 2)
        let radiusY: CGFloat = (size.height - Self.tile) / 2

        ZStack {
            if t < 1.6 {
                dissolvingCode(t: t)
                    .frame(width: 132, height: 132)
                    .position(center)
            }

            let icon = Ease.outBack(progress(t, from: 0.75, over: 0.55))
            LensAppIcon(size: 112)
                .scaleEffect(0.6 + 0.4 * icon)
                .opacity(min(1, icon * 1.4))
                .position(center)

            ForEach(Array(Self.kinds.enumerated()), id: \.element) { index, kind in
                let angle = Angle.degrees(Double(index) * 60 + 180).radians
                let target = CGPoint(x: center.x + radiusX * cos(angle), y: center.y + radiusY * sin(angle) * 0.92)
                let p = Ease.outBack(progress(t, from: 1.05 + Double(index) * 0.08, over: 0.6))
                KindTile(kind: kind, size: Self.tile)
                    .scaleEffect(0.35 + 0.65 * p)
                    .opacity(min(1, p * 1.6))
                    .position(x: center.x + (target.x - center.x) * p, y: center.y + (target.y - center.y) * p)
            }
        }
    }

    /// Modules shrink and fade, the center first, as if the code is being understood.
    private func dissolvingCode(t: Double) -> some View {
        Canvas { context, size in
            guard let matrix = Self.matrix else { return }
            let cell = size.width / CGFloat(matrix.size)
            let mid = Double(matrix.size - 1) / 2
            let maxDistance = (mid * mid * 2).squareRoot()
            for row in 0..<matrix.size {
                for column in 0..<matrix.size where matrix.isDark(row: row, column: column) {
                    let dx = Double(column) - mid, dy = Double(row) - mid
                    let distance = (dx * dx + dy * dy).squareRoot() / maxDistance
                    let local = progress(t, from: 0.25 + distance * 0.55, over: 0.4)
                    guard local < 1 else { continue }
                    let side = cell * (1 - local)
                    let rect = CGRect(
                        x: CGFloat(column) * cell + (cell - side) / 2,
                        y: CGFloat(row) * cell + (cell - side) / 2,
                        width: side,
                        height: side
                    )
                    context.opacity = 1 - local
                    context.fill(Path(roundedRect: rect, cornerRadius: side * 0.3 * local), with: .foreground)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private func progress(_ t: Double, from begin: Double, over duration: Double) -> Double {
        min(1, max(0, (t - begin) / duration))
    }
}

private enum Ease {
    /// Overshoots slightly, then settles: a spring without the physics.
    static func outBack(_ x: Double) -> Double {
        let c1 = 1.4, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }
}

#Preview {
    WelcomeHero()
        .padding()
}
