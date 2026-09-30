import SwiftUI

/// Home's hero: a glass loupe with the brand's refraction rim and a viewfinder inside. The rim's
/// colors drift, a scan beam sweeps the brackets and a glint crosses the glass now and then, so it
/// reads as a lens rather than a button; it holds still with Reduce Motion. The brackets are the
/// scanner's reticle: opening the camera, they fly out of the lens.
struct ScanLensButton: View {
    static let defaultDiameter: CGFloat = 116
    static let rimWidth: CGFloat = 5
    var diameter: CGFloat = ScanLensButton.defaultDiameter
    /// Off while something covers Home, so the idle motion doesn't cost anything unseen.
    var isAnimating = true
    /// Bumped when the camera closes back into the lens, which catches it with a bounce.
    var catchTrigger = 0
    /// Finger down (true) and up or off (false), before `action`.
    var onPressChange: (Bool) -> Void = { _ in }
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
        .buttonStyle(LensPressStyle(onPressChange: onPressChange))
        .keyframeAnimator(initialValue: CGFloat(1), trigger: catchTrigger) { content, scale in
            content.scaleEffect(reduceMotion ? 1 : scale)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(1.1, duration: 0.1)
                SpringKeyframe(1, duration: 0.5, spring: .init(response: 0.35, dampingRatio: 0.45))
            }
        }
        .accessibilityLabel("Scan")
        .accessibilityHint("Opens the camera")
        .accessibilityIdentifier("scanLens")
    }

    /// Where the brackets sit, for a default-sized lens centered on `center`.
    static func glyphQuad(around center: CGPoint, pressed: Bool = false) -> Quad {
        let press = pressed ? LensFace.pressedScale : 1
        let side = defaultDiameter * LensFace.glyphScale * press * (pressed ? LensFace.pressedGlyphScale : 1)
        let mid = CGPoint(x: center.x, y: center.y + LensFace.glyphOffset * press)
        return Quad(rect: CGRect(x: mid.x - side / 2, y: mid.y - side / 2, width: side, height: side))
    }
}

struct LensFace: View {
    var diameter: CGFloat
    var time: TimeInterval

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.lensIsPressed) private var isPressed

    /// One turn of the rim every 14 seconds.
    private var rimAngle: Angle { .degrees((time / 14).truncatingRemainder(dividingBy: 1) * 360) }

    /// 0...1 while the glint crosses (about a second every six), otherwise nil.
    private var glintPhase: Double? {
        let cycle = time.truncatingRemainder(dividingBy: 6)
        return cycle < 1.1 ? cycle / 1.1 : nil
    }

    /// The brackets' side as a fraction of the lens, and their center's offset from the lens's.
    static let glyphScale: CGFloat = 0.34
    static let glyphOffset: CGFloat = -13
    /// How far the lens and its brackets press in under a finger.
    static let pressedScale: CGFloat = 0.88
    static let pressedGlyphScale: CGFloat = 0.72

    var body: some View {
        let rim = ScanLensButton.rimWidth
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

            VStack(spacing: 5) {
                ScanGlyph(time: time)
                    .frame(width: diameter * Self.glyphScale, height: diameter * Self.glyphScale)
                    // Under the finger the brackets pinch in, as if closing on a code.
                    .scaleEffect(isPressed ? Self.pressedGlyphScale : 1)
                    .animation(.spring(response: 0.3, dampingFraction: isPressed ? 0.8 : 0.4), value: isPressed)
                Text("Scan")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    // Stay inside the lens: "Сканировать", "Skannaa", "Σάρωση" are wider than "Scan".
                    .frame(maxWidth: diameter * 0.78)
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

/// Four rounded brackets (the scanner's reticle in miniature) with a cyan beam that sweeps down
/// through them every few seconds, leaving a short glowing trail.
private struct ScanGlyph: View {
    var time: TimeInterval

    /// 0...1 while the beam travels (about 1.2 s of every 3.2 s), otherwise nil.
    private var beamPhase: Double? {
        let cycle = (time + 1.4).truncatingRemainder(dividingBy: 3.2)
        return cycle < 1.2 ? cycle / 1.2 : nil
    }

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let rect = CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side)
            let line = side * 0.085
            let brackets = Quad(rect: rect.insetBy(dx: line / 2, dy: line / 2))
                .bracketPath(armLength: side * 0.3, cornerRadius: side * 0.2)
            context.stroke(brackets, with: .color(.white), style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))

            // A tiny code in the middle: three finder dots, so it reads as "scan a code".
            let dot = side * 0.14
            let inner = rect.insetBy(dx: side * 0.3, dy: side * 0.3)
            for origin in [inner.origin, CGPoint(x: inner.maxX - dot, y: inner.minY), CGPoint(x: inner.minX, y: inner.maxY - dot)] {
                context.fill(Path(roundedRect: CGRect(origin: origin, size: CGSize(width: dot, height: dot)), cornerRadius: dot * 0.3), with: .color(.white.opacity(0.9)))
            }
            context.fill(
                Path(roundedRect: CGRect(x: inner.maxX - dot, y: inner.maxY - dot, width: dot, height: dot), cornerRadius: dot * 0.3),
                with: .color(.white.opacity(0.45))
            )

            guard let phase = beamPhase else { return }
            let eased = phase * phase * (3 - 2 * phase)
            let travel = rect.insetBy(dx: side * 0.12, dy: side * 0.16)
            let y = travel.minY + travel.height * eased
            // Fade in at the top and out at the bottom.
            let strength = sin(.pi * phase)
            let cyan = LunetPalette.rims[0]

            var trail = context
            trail.opacity = 0.55 * strength
            trail.fill(
                Path(CGRect(x: travel.minX, y: y - side * 0.28, width: travel.width, height: side * 0.28)),
                with: .linearGradient(
                    Gradient(colors: [cyan.opacity(0), cyan.opacity(0.5)]),
                    startPoint: CGPoint(x: 0, y: y - side * 0.28),
                    endPoint: CGPoint(x: 0, y: y)
                )
            )

            var beam = context
            beam.opacity = strength
            beam.addFilter(.shadow(color: cyan, radius: side * 0.1))
            beam.fill(
                Path(roundedRect: CGRect(x: travel.minX, y: y - line * 0.35, width: travel.width, height: line * 0.7), cornerRadius: line),
                with: .color(.white)
            )
        }
        .accessibilityHidden(true)
    }
}

/// Presses in deep with a tick, and springs back with a wobble.
private struct LensPressStyle: ButtonStyle {
    var onPressChange: (Bool) -> Void
    @AppStorage(Pref.haptics) private var haptics = Pref.Default.haptics

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.lensIsPressed, configuration.isPressed)
            .scaleEffect(configuration.isPressed ? LensFace.pressedScale : 1)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(
                configuration.isPressed ? .spring(response: 0.2, dampingFraction: 0.8) : .spring(response: 0.35, dampingFraction: 0.45),
                value: configuration.isPressed
            )
            .sensoryFeedback(trigger: configuration.isPressed) { _, pressed in
                haptics && pressed ? .impact(weight: .light, intensity: 0.9) : nil
            }
            .onChange(of: configuration.isPressed) { _, pressed in onPressChange(pressed) }
    }
}

private extension EnvironmentValues {
    @Entry var lensIsPressed = false
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
