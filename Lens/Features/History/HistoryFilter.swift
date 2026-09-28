import Foundation
import SwiftData

/// A chip in History's filter bar.
enum HistoryFilter: Hashable, Identifiable {
    case all
    case pinned
    case created
    case kind(CodeKind)

    static let chips: [HistoryFilter] = [.all, .pinned, .created] + CodeKind.historyFilters.map(HistoryFilter.kind)

    var id: String {
        switch self {
        case .all: "all"
        case .pinned: "pinned"
        case .created: "created"
        case .kind(let kind): kind.rawValue
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .all: "All"
        case .pinned: "Pinned"
        case .created: "Created"
        case .kind(let kind):
            switch kind {
            case .link: "Links"
            case .product: "Products"
            case .contact: "Contacts"
            case .event: "Events"
            case .travel: "Travel"
            default: kind.title
            }
        }
    }

    var kind: CodeKind? {
        if case .kind(let kind) = self { kind } else { nil }
    }
}

/// What History is currently showing: a filter chip plus the search text.
struct HistoryCriteria: Hashable {
    var filter: HistoryFilter = .all
    var search: String = ""

    var trimmedSearch: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Records matching the chip and search, created within `range`, optionally restricted by pin state.
    func predicate(in range: Range<Date> = Date.distantPast..<Date.distantFuture, pinned: Bool? = nil) -> Predicate<ScanRecord> {
        let anyKind = filter.kind == nil
        let kindRaw = filter.kind?.rawValue ?? ""
        let createdOnly = filter == .created
        let createdRaw = ScanRecord.Origin.created.rawValue
        let anyPin = pinned == nil
        let pinValue = pinned ?? false
        let start = range.lowerBound
        let end = range.upperBound
        let term = trimmedSearch
        let anyText = term.isEmpty

        return #Predicate<ScanRecord> { record in
            record.createdAt >= start && record.createdAt < end
                && (anyKind || record.kindRaw == kindRaw)
                && (!createdOnly || record.originRaw == createdRaw)
                && (anyPin || record.isPinned == pinValue)
                && (anyText
                    || record.title.localizedStandardContains(term)
                    || record.raw.localizedStandardContains(term)
                    || record.subtitle.localizedStandardContains(term)
                    || (record.placeName ?? "").localizedStandardContains(term))
        }
    }
}
