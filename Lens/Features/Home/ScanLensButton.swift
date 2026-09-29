import SwiftUI

/// Home's hero: a glass loupe with the brand's refraction rim. The rim's colors drift slowly and a
/// glint crosses the glass now and then, so it reads as a lens rather than a button; it holds still
/// with Reduce Motion.
struct ScanLensButton: View {
    var diameter: CGFloat = 116
    /// Off while something covers Home, so the idle motion doesn't cost anything unseen.
    var isAnimating = true
    var action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Group {
                if reduceMotion {
                    LensFace(diameter: diameter, time: 0)
                } else {
                    TimelineView(.animation(minimumInterval: 1 / 30, paused: !isAnimating)) { context in
                        LensFace(diameter: diameter, time: context.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
        }
        .buttonStyle(LensPressStyle())
        .accessibilityLabel("Scan")
        .accessibilityHint("Opens the camera")
        .accessibilityIdentifier("scanLens")
    }
}

private struct LensFace: View {
    var diameter: CGFloat
    var time: TimeInterval

    @Environment(\.colorScheme) private var colorScheme

    /// One turn of the rim every 14 seconds.
    private var rimAngle: Angle { .degrees((time / 14).truncatingRemainder(dividingBy: 1) * 360) }

    /// 0...1 while the glint crosses (about a second every six), otherwise nil.
    private var glintPhase: Double? {
        let cycle = time.truncatingRemainder(dividingBy: 6)
        return cycle < 1.1 ? cycle / 1.1 : nil
    }

    var body: some View {
        let rim: CGFloat = 5
        ZStack {
            Circle()
                .fill(AngularGradient(
                    colors: LunetPalette.rims + [LunetPalette.rims[0]],
                    center: .center,
                    angle: rimAngle
                ))

            Circle()
                .fill(RadialGradient(
                    colors: [Color(hex: 0x21465A), Color(hex: 0x0B1A24), Color(hex: 0x060D13)],
                    center: UnitPoint(x: 0.35, y: 0.3),
                    startRadius: 0,
                    endRadius: diameter * 0.62
                ))
                .padding(rim)

            // Specular sheen: light from the top left.
            Circle()
                .fill(LinearGradient(
                    colors: [.white.opacity(0.32), .white.opacity(0.04), .clear],
                    startPoint: .topLeading,
                    endPoint: .center
                ))
                .padding(rim + 2)
                .blendMode(.screen)

            if let glintPhase {
                glint(phase: glintPhase)
            }

            VStack(spacing: 6) {
                LunetGlyph()
                    .foregroundStyle(.white)
                    .frame(width: diameter * 0.3)
                Text("Scan")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .offset(y: 2)
        }
        .frame(width: diameter, height: diameter)
        .compositingGroup()
        .shadow(color: LunetPalette.rims[0].opacity(colorScheme == .dark ? 0.35 : 0.3), radius: 18, y: 8)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.18), radius: 6, y: 3)
    }

    /// A soft diagonal streak that sweeps across the glass.
    private func glint(phase: Double) -> some View {
        let eased = phase * phase * (3 - 2 * phase)
        return Rectangle()
            .fill(LinearGradient(
                colors: [.clear, .white.opacity(0.28), .clear],
                startPoint: .leading,
                endPoint: .trailing
            ))
            .frame(width: diameter * 0.28, height: diameter * 1.6)
            .rotationEffect(.degrees(28))
            .offset(x: -diameter + eased * diameter * 2)
            .mask(Circle().padding(5))
            .blendMode(.screen)
            .allowsHitTesting(false)
    }
}

private struct LensPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 40) {
        ScanLensButton {}
        ScanLensButton {}.environment(\.colorScheme, .dark)
    }
    .padding(40)
    .background(Color(.systemGroupedBackground))
}
#endif
