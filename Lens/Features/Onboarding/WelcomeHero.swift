import SwiftUI

/// The one choreographed moment: the eye opens, the iris blades swirl out into place around the
/// code-eye pupil, it blinks once, then the iris keeps a slow drift. Reduce Motion shows the icon.
struct WelcomeHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Pref.haptics) private var haptics = Pref.Default.haptics
    @State private var start: Date?
    @State private var blinked = false

    var body: some View {
        Group {
            if reduceMotion {
                OjitoMark()
            } else {
                TimelineView(.animation(paused: start == nil)) { timeline in
                    let elapsed = start.map { timeline.date.timeIntervalSince($0) } ?? 0
                    OjitoMark(pose: WelcomeMotion.pose(at: elapsed))
                }
            }
        }
        .frame(maxWidth: 280)
        .padding(.vertical, 16)
        .accessibilityHidden(true)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: blinked) { _, didBlink in
            didBlink && haptics
        }
        .task {
            guard !reduceMotion else { return }
            start = .now
            try? await Task.sleep(for: .seconds(WelcomeMotion.blinkStart + WelcomeMotion.blinkClose))
            blinked = true
        }
    }
}

/// The Welcome animation as a pure function of time, so it can be tested and scrubbed.
nonisolated enum WelcomeMotion {
    static let openDuration = 0.3
    static let bladeStart = 0.12
    static let bladeStagger = 0.06
    static let bladeDuration = 0.55
    static let pupilStart = 0.25
    static let pupilDuration = 0.4
    static let blinkStart = 0.95
    static let blinkClose = 0.09
    static let blinkOpen = 0.2
    /// When the pose is exactly the icon; the idle drift starts from here.
    static let duration = blinkStart + blinkClose + blinkOpen
    /// Idle: degrees per second the iris turns, and how much each blade breathes.
    static let driftSpeed = 4.0
    static let breath = 0.025

    static func pose(at t: Double) -> OjitoMark.Pose {
        var pose = OjitoMark.Pose()
        pose.openness = openness(at: t)
        pose.pupil = Ease.outBack(progress(t, from: pupilStart, over: pupilDuration))
        pose.blades = (0..<OjitoGeometry.bladeCount).map { index in
            let begin = bladeStart + Double(index) * bladeStagger
            return Ease.outBack(progress(t, from: begin, over: bladeDuration)) + idleBreath(index, at: t)
        }
        pose.spin = .degrees(max(0, t - duration) * driftSpeed)
        return pose
    }

    private static func openness(at t: Double) -> Double {
        if t < blinkStart {
            return Ease.outCubic(progress(t, from: 0, over: openDuration))
        }
        let shut = 0.03
        if t < blinkStart + blinkClose {
            let p = progress(t, from: blinkStart, over: blinkClose)
            return 1 - (1 - shut) * p * p
        }
        let p = progress(t, from: blinkStart + blinkClose, over: blinkOpen)
        return shut + (1 - shut) * Ease.outCubic(p)
    }

    /// Starts at zero and fades in, so the handoff from the entrance has no jump.
    private static func idleBreath(_ index: Int, at t: Double) -> Double {
        let idle = t - duration
        guard idle > 0 else { return 0 }
        let fadeIn = min(1, idle / 2)
        return breath * fadeIn * sin(idle * 1.4 + Double(index) * 1.3)
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
}

#Preview {
    WelcomeHero()
        .padding()
}
