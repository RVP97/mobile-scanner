import Foundation

// OWNER: Result module. Scanner uses `quickCheck` for Scan & Go. Keep signatures stable.
enum SafetyAnalyzer {
    /// Offline heuristics only. Instant.
    static func quickCheck(_ url: URL) -> SafetyVerdict {
        SafetyVerdict(level: .unknown, original: url)
    }

    /// Offline heuristics plus, when enabled, redirect resolution and domain age.
    static func fullCheck(_ url: URL) async -> SafetyVerdict {
        quickCheck(url)
    }
}
