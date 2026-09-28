import SwiftUI

/// The one choreographed moment: the loupe glides in over the little code, the finder under it
/// snaps into focus, the rim's colors sweep once and the sparkle glints. Then it rests, with a
/// slow glint every few seconds. Reduce Motion shows the icon.
struct WelcomeHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Pref.haptics) private var haptics = Pref.Default.haptics
    @State private var start: Date?
    @State private var snapped = false

    /// A moment to hold the animation at, for screenshots (DEBUG only).
    private var frozenTime: Double? {
        #if DEBUG
        QAHarness.welcomeTime
        #else
        nil
        #endif
    }

    var body: some View {
        Group {
            if reduceMotion {
                LunetMark()
            } else {
                TimelineView(.animation(paused: start == nil)) { timeline in
                    let elapsed = frozenTime ?? start.map { timeline.date.timeIntervalSince($0) } ?? 0
                    LunetMark(pose: WelcomeMotion.pose(at: elapsed))
                }
            }
        }
        .frame(maxWidth: 248)
        .padding(.vertical, 8)
        .accessibilityHidden(true)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: snapped) { _, didSnap in
            didSnap && haptics
        }
        .task {
            guard !reduceMotion else { return }
            start = .now
            try? await Task.sleep(for: .seconds(WelcomeMotion.focusStart + WelcomeMotion.focusDuration * 0.4))
            snapped = true
        }
    }
}

/// The Welcome animation as a pure function of time, so it can be tested and scrubbed.
nonisolated enum WelcomeMotion {
    static let codeDuration = 0.2
    static let glideStart = 0.05
    static let glideDuration = 0.6
    /// Where the lens starts, in icon units: over the code's data, down and to the right.
    static let glideFrom = CGSize(width: 210, height: 230)
    static let focusStart = 0.5
    static let focusDuration = 0.3
    static let sweepStart = 0.6
    static let sweepDuration = 0.5
    static let glintStart = 0.85
    static let glintDuration = 0.35
    /// When the pose is exactly the icon; the idle glint starts from here.
    static let duration = glintStart + glintDuration
    /// Idle: a glint every `idlePeriod` seconds, lasting `idleGlint`.
    static let idlePeriod = 4.5
    static let idleGlint = 0.7

    static func pose(at t: Double) -> LunetMark.Pose {
        var pose = LunetMark.Pose()
        pose.code = Ease.outCubic(progress(t, from: 0, over: codeDuration))

        let glide = Ease.outQuart(progress(t, from: glideStart, over: glideDuration))
        pose.lensOffset = CGSize(width: glideFrom.width * (1 - glide), height: glideFrom.height * (1 - glide))
        pose.lensOpacity = Ease.outCubic(progress(t, from: glideStart, over: 0.2))

        pose.focus = Ease.outBack(progress(t, from: focusStart, over: focusDuration))

        let sweep = progress(t, from: sweepStart, over: sweepDuration)
        if sweep > 0, sweep < 1 {
            pose.refraction = .degrees(360 * Ease.inOutCubic(sweep))
            pose.spread = 1 + 0.8 * sin(.pi * sweep)
        }

        let glint = progress(t, from: glintStart, over: glintDuration)
        pose.glint = Ease.outBack(glint)
        pose.glintSpin = .degrees(-90 * (1 - Ease.outCubic(glint)))

        applyIdle(to: &pose, at: t)
        return pose
    }

    /// Between glints the pose is exactly the icon. Each glint turns the star a quarter turn,
    /// which lands on the same shape, so the loop has no seam.
    private static func applyIdle(to pose: inout LunetMark.Pose, at t: Double) {
        let idle = t - duration
        guard idle > 0 else { return }
        let phase = idle.truncatingRemainder(dividingBy: idlePeriod) - (idlePeriod - idleGlint)
        guard phase > 0 else { return }
        let p = phase / idleGlint
        let swell = sin(.pi * p)
        pose.glint = 1 + 0.3 * swell
        pose.glintSpin = .degrees(90 * Ease.inOutCubic(p))
        pose.spread = 1 + 0.35 * swell
    }

    private static func progress(_ t: Double, from begin: Double, over length: Double) -> Double {
        min(1, max(0, (t - begin) / length))
    }
}

private nonisolated enum Ease {
    /// Overshoots slightly, then settles: a spring without the physics.
    static func outBack(_ x: Double) -> Double {
        let c1 = 1.4, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }

    static func outCubic(_ x: Double) -> Double {
        1 - pow(1 - x, 3)
    }

    static func outQuart(_ x: Double) -> Double {
        1 - pow(1 - x, 4)
    }

    static func inOutCubic(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }
}

#Preview {
    WelcomeHero()
        .padding()
}
