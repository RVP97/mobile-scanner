import Foundation
import Observation

/// Follows the most prominent code for the reticle and reports codes once they're stable.
/// Shared by the full scanner and the embeddable `CodeScannerView`.
@Observable
final class ScanTracker {
    /// The code the reticle should hug, or nil to rest in the center.
    private(set) var trackedQuad: Quad?
    private(set) var isPaused = false
    /// Every code in view while more than one is, so the person can tap the one they mean.
    private(set) var choices: [Choice] = []

    struct Choice: Identifiable, Equatable {
        var read: CodeRead
        var payload: Payload
        var id: String { read.raw }
    }

    @ObservationIgnored private var stabilizer = DetectionStabilizer()
    @ObservationIgnored private var releaseTask: Task<Void, Never>?
    @ObservationIgnored private var crowd = CrowdGate()
    @ObservationIgnored private var payloads: [String: Payload] = [:]

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

    /// Feeds one frame when the scanner should wait to be told which code to open. Returns true while
    /// several codes are (or were just) in view; the caller then doesn't lock on anything by itself.
    func holdIfCrowded(_ reads: [CodeRead]) -> Bool {
        guard !isPaused else { return false }
        var seen = Set<String>()
        let distinct = reads
            .sorted { $0.quad.area > $1.quad.area }
            .filter { seen.insert($0.raw).inserted }
        let now = Self.now
        guard crowd.isCrowded(distinctCount: distinct.count, at: now) else {
            if !choices.isEmpty { clearChoices() }
            return false
        }
        if distinct.count >= 2 {
            let next = distinct.map { read in
                let payload = payloads[read.raw] ?? PayloadParser.parse(read.raw, symbology: read.symbology)
                payloads[read.raw] = payload
                return Choice(read: read, payload: payload)
            }
            // Keep a stable order (left to right, then top to bottom) so pins don't swap places.
            choices = next.sorted {
                abs($0.read.quad.center.y - $1.read.quad.center.y) > 60
                    ? $0.read.quad.center.y < $1.read.quad.center.y
                    : $0.read.quad.center.x < $1.read.quad.center.x
            }
        }
        trackedQuad = nil
        return true
    }

    func setPaused(_ paused: Bool) {
        guard paused != isPaused else { return }
        isPaused = paused
        releaseTask?.cancel()
        trackedQuad = nil
        clearChoices()
        if !paused { stabilizer.restartCooldowns(at: Self.now) }
    }

    /// Treats a code as handled (e.g. it came from a photo) so the camera doesn't fire on it right away.
    func suppress(_ raw: String) {
        stabilizer.suppress(raw, at: Self.now)
    }

    /// Drops the pins (e.g. Multi-scan came on, and it takes every code anyway).
    func clearChoices() {
        choices = []
        payloads.removeAll()
        crowd.reset()
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

/// Decides when the view is "crowded": two or more different codes at once. It stays crowded for a
/// moment after the last such frame, so a code the camera misses for a frame or two doesn't leave
/// the other one to open by itself.
struct CrowdGate {
    var holdDuration: TimeInterval = 0.8
    private var lastCrowdedAt: TimeInterval?

    mutating func isCrowded(distinctCount: Int, at now: TimeInterval) -> Bool {
        if distinctCount >= 2 {
            lastCrowdedAt = now
            return true
        }
        if let last = lastCrowdedAt, now - last < holdDuration { return true }
        lastCrowdedAt = nil
        return false
    }

    mutating func reset() {
        lastCrowdedAt = nil
    }
}
