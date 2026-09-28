import Foundation

// OWNER: Result module. Keep these signatures stable; other modules call them.
enum PayloadParser {
    static func parse(_ raw: String, symbology: Symbology) -> Payload {
        if let url = URL(string: raw), url.scheme?.hasPrefix("http") == true { return .link(url) }
        return .text(raw)
    }
}

extension Payload {
    /// Primary line for lists and headers ("atlas-coffee.co", "Atlas Guest").
    var displayTitle: String {
        switch self {
        case .link(let url): url.host() ?? url.absoluteString
        case .text(let text): text
        default: kind.rawValue
        }
    }

    /// Secondary line for lists.
    var displaySubtitle: String { "" }
}
