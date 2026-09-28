import Foundation

/// Outcome of checking a link before it's opened.
struct SafetyVerdict: Hashable, Sendable {
    enum Level: String, Codable, Sendable, Comparable {
        case safe, caution, danger, unknown

        private var rank: Int {
            switch self {
            case .unknown: 0
            case .safe: 1
            case .caution: 2
            case .danger: 3
            }
        }
        static func < (a: Level, b: Level) -> Bool { a.rank < b.rank }
    }

    struct Finding: Hashable, Sendable, Identifiable {
        var id: String { title }
        var level: Level
        var title: String        // "Registered 3 days ago"
        var detail: String = ""  // "Scam domains are usually brand new."
        var symbol: String       // SF Symbol
    }

    var level: Level
    /// The URL as printed in the code.
    var original: URL
    /// Every hop we followed, ending with the real destination. Empty when not resolved.
    var redirectChain: [URL] = []
    var findings: [Finding] = []

    var destination: URL { redirectChain.last ?? original }
}
