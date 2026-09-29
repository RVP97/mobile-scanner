import Foundation

/// The scanner closes itself after a stretch with nothing to read, so the camera never runs
/// forgotten in a pocket. Any detection or touch starts the stretch over; the last few seconds
/// show as a draining ring on Close.
nonisolated struct ScannerIdleClock: Equatable, Sendable {
    /// Seconds without a code (or a touch) before the scanner closes.
    static let timeout: TimeInterval = 30
    /// Seconds before closing that the countdown ring appears.
    static let warning: TimeInterval = 5

    private(set) var lastActivity: TimeInterval
    /// While paused (a result or the photo picker is up) time doesn't count.
    private(set) var pausedAt: TimeInterval?

    init(now: TimeInterval) {
        lastActivity = now
    }

    /// A detection or a touch.
    mutating func reset(at now: TimeInterval) {
        lastActivity = now
        if pausedAt != nil { pausedAt = now }
    }

    mutating func pause(at now: TimeInterval) {
        guard pausedAt == nil else { return }
        pausedAt = now
    }

    /// Resumes with the time already spent idle still counted.
    mutating func resume(at now: TimeInterval) {
        guard let pausedAt else { return }
        lastActivity += now - pausedAt
        self.pausedAt = nil
    }

    var isPaused: Bool { pausedAt != nil }

    func remaining(at now: TimeInterval) -> TimeInterval {
        let elapsed = (pausedAt ?? now) - lastActivity
        return max(0, Self.timeout - elapsed)
    }

    func isExpired(at now: TimeInterval) -> Bool { remaining(at: now) <= 0 }

    /// Whether the countdown ring shows.
    func isWarning(at now: TimeInterval) -> Bool {
        let left = remaining(at: now)
        return left > 0 && left <= Self.warning
    }

    /// The ring's fill, 1 when it appears down to 0 at close.
    func warningProgress(at now: TimeInterval) -> Double {
        min(1, remaining(at: now) / Self.warning)
    }
}
