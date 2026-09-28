import ActivityKit
import Foundation

/// Live Activity for a multi-scan session: how many codes, which kinds, and the latest one.
nonisolated struct MultiScanAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var count: Int
        /// `CodeKind` raw values, most recent first, without repeats.
        var kinds: [String]
        /// Title of the most recent code ("atlas-coffee.co/menu").
        var latest: String
        var updatedAt: Date

        /// Keeps the newest distinct kinds, capped so the Dynamic Island never overflows.
        static func make(count: Int, kinds: [String], latest: String, at date: Date = .now) -> ContentState {
            var seen = Set<String>()
            let recentFirst = kinds.reversed().filter { seen.insert($0).inserted }
            return ContentState(count: count, kinds: Array(recentFirst.prefix(maxKinds)), latest: latest, updatedAt: date)
        }

        static let maxKinds = 4
    }

    var startedAt: Date
}
