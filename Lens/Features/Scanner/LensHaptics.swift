import CoreHaptics
import UIKit

/// The scanner's opening and closing, felt: a rising whoosh as the lens widens that ends in a crisp
/// click when the brackets land, and a soft thunk when the camera settles back into the lens.
final class LensHaptics {
    static let shared = LensHaptics()

    private var engine: CHHapticEngine?

    private var isEnabled: Bool {
        Pref.bool(Pref.haptics, default: Pref.Default.haptics) && CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    /// Opening: a swell that tightens as the lens widens, then the click of the brackets landing.
    func open() {
        play(
            events: [
                continuous(at: 0, duration: 0.3, intensity: 0.5, sharpness: 0.15),
                transient(at: 0.32, intensity: 1, sharpness: 0.85),
                transient(at: 0.42, intensity: 0.35, sharpness: 0.6),
            ],
            curves: [
                CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                    .init(relativeTime: 0, value: 0.3), .init(relativeTime: 0.3, value: 1),
                ], relativeTime: 0),
                CHHapticParameterCurve(parameterID: .hapticSharpnessControl, controlPoints: [
                    .init(relativeTime: 0, value: 0), .init(relativeTime: 0.3, value: 0.5),
                ], relativeTime: 0),
            ]
        )
    }

    /// Closing: a short fall away.
    func close() {
        play(
            events: [continuous(at: 0, duration: 0.22, intensity: 0.35, sharpness: 0.2)],
            curves: [
                CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                    .init(relativeTime: 0, value: 1), .init(relativeTime: 0.22, value: 0.2),
                ], relativeTime: 0),
            ]
        )
    }

    /// The camera back in the lens: a round, heavy tap.
    func settle() {
        play(events: [transient(at: 0, intensity: 0.9, sharpness: 0.3)])
    }

    // MARK: Engine

    private func play(events: [CHHapticEvent], curves: [CHHapticParameterCurve] = []) {
        guard isEnabled, let engine = startedEngine() else { return }
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            self.engine = nil
        }
    }

    private func startedEngine() -> CHHapticEngine? {
        if engine == nil {
            engine = try? CHHapticEngine()
            engine?.isAutoShutdownEnabled = true
            engine?.playsHapticsOnly = true
            engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
            engine?.stoppedHandler = { [weak self] _ in self?.engine = nil }
        }
        try? engine?.start()
        return engine
    }

    private func transient(at time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time)
    }

    private func continuous(at time: TimeInterval, duration: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time, duration: duration)
    }
}
