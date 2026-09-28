import Foundation

/// One code seen in one camera frame, already mapped to screen space.
struct CodeRead: Hashable {
    var raw: String
    var symbology: Symbology
    var quad: Quad

    var scannedCode: ScannedCode {
        ScannedCode(raw: raw, symbology: symbology, corners: quad.corners)
    }
}

/// Decides when a code is read reliably enough to act on, and keeps a handled code from firing again.
///
/// A payload locks once it has been read in `requiredReads` consecutive frames, each no more than
/// `maximumGap` apart (about 60–120 ms at camera frame rates). After it locks, the payload stays quiet
/// until it has been out of view for `cooldown` seconds, so pointing at the same code doesn't re-open it.
struct DetectionStabilizer {
    var requiredReads = 2
    var maximumGap: TimeInterval = 0.25
    var cooldown: TimeInterval = 2

    private struct Candidate {
        var reads: Int
        var lastSeen: TimeInterval
    }

    private var candidates: [String: Candidate] = [:]
    /// Handled payloads and when they were last seen (or handled).
    private var quiet: [String: TimeInterval] = [:]

    /// Feeds one frame. Returns the reads that just became stable, largest first; they count as handled.
    mutating func ingest(_ reads: [CodeRead], at now: TimeInterval) -> [CodeRead] {
        quiet = quiet.filter { now - $0.value < cooldown }
        candidates = candidates.filter { now - $0.value.lastSeen <= maximumGap }

        var locked: [CodeRead] = []
        var seen = Set<String>()
        for read in reads.sorted(by: { $0.quad.area > $1.quad.area }) where seen.insert(read.raw).inserted {
            if quiet[read.raw] != nil {
                quiet[read.raw] = now
                continue
            }
            var candidate = candidates[read.raw] ?? Candidate(reads: 0, lastSeen: now)
            candidate.reads += 1
            candidate.lastSeen = now
            if candidate.reads >= requiredReads {
                candidates[read.raw] = nil
                quiet[read.raw] = now
                locked.append(read)
            } else {
                candidates[read.raw] = candidate
            }
        }
        // Consecutive means consecutive: anything not in this frame starts over.
        candidates = candidates.filter { seen.contains($0.key) }
        return locked
    }

    /// Marks a payload as handled without it having been read by the camera (e.g. from a photo).
    mutating func suppress(_ raw: String, at now: TimeInterval) {
        quiet[raw] = now
        candidates[raw] = nil
    }

    /// Restarts every cooldown. Call when detection resumes after a pause (a result was open, the app was
    /// in the background) so the code that caused the pause doesn't fire again the instant it's back.
    mutating func restartCooldowns(at now: TimeInterval) {
        for key in quiet.keys { quiet[key] = now }
        candidates.removeAll()
    }

    mutating func reset() {
        candidates.removeAll()
        quiet.removeAll()
    }
}
