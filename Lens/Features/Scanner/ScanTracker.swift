import Foundation
import Observation

/// Follows the most prominent code for the reticle and reports codes once they're stable.
/// Shared by the full scanner and the embeddable `CodeScannerView`.
@Observable
final class ScanTracker {
    /// The code the reticle should hug, or nil to rest in the center.
    private(set) var trackedQuad: Quad?
    private(set) var isPaused = false

    @ObservationIgnored private var stabilizer = DetectionStabilizer()
    @ObservationIgnored private var releaseTask: Task<Void, Never>?

    /// How long the reticle holds on a code after the last read, so a dropped frame doesn't make it jump.
    private let holdDuration: Duration = .milliseconds(350)

    /// Feeds one frame; returns the codes that just became stable, largest first.
    func ingest(_ reads: [CodeRead]) -> [CodeRead] {
        guard !isPaused else { return [] }
        if let primary = reads.max(by: { $0.quad.area < $1.quad.area }) {
            trackedQuad = primary.quad
            scheduleRelease()
        }
        return stabilizer.ingest(reads, at: Self.now)
    }

    func setPaused(_ paused: Bool) {
        guard paused != isPaused else { return }
        isPaused = paused
        releaseTask?.cancel()
        trackedQuad = nil
        if !paused { stabilizer.restartCooldowns(at: Self.now) }
    }

    /// Treats a code as handled (e.g. it came from a photo) so the camera doesn't fire on it right away.
    func suppress(_ raw: String) {
        stabilizer.suppress(raw, at: Self.now)
    }

    private func scheduleRelease() {
        releaseTask?.cancel()
        releaseTask = Task { [holdDuration] in
            try? await Task.sleep(for: holdDuration)
            guard !Task.isCancelled else { return }
            trackedQuad = nil
        }
    }

    private static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
}
