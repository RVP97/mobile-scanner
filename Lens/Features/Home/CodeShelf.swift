import Foundation
import SwiftData

/// Which codes appear under "Your codes" on Home, and in what order.
///
/// Everything the person made, plus every scan they pinned. A trip in the next few days rises to
/// the front (soonest first), the way Wallet surfaces a boarding pass; the rest follow newest first.
/// A code saved twice (made, then scanned and pinned) shows once.
enum CodeShelf {
    /// How far ahead a boarding pass counts as upcoming.
    static let upcomingDays = 7

    /// What ordering needs to know about a code.
    struct Entry: Equatable {
        var raw: String
        var createdAt: Date
        /// The flight day, for boarding passes.
        var tripDate: Date?
    }

    /// Records for the shelf: created or pinned.
    static var descriptor: FetchDescriptor<ScanRecord> {
        let created = ScanRecord.Origin.created.rawValue
        return FetchDescriptor(
            predicate: #Predicate { $0.isPinned || $0.originRaw == created },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }

    /// Indices into `entries`, in shelf order, without repeats of the same content.
    static func order(_ entries: [Entry], now: Date, calendar: Calendar = .current) -> [Int] {
        let today = calendar.startOfDay(for: now)
        let horizon = calendar.date(byAdding: .day, value: upcomingDays, to: today) ?? today

        func upcoming(_ entry: Entry) -> Date? {
            guard let trip = entry.tripDate else { return nil }
            let day = calendar.startOfDay(for: trip)
            return day >= today && day <= horizon ? day : nil
        }

        let sorted = entries.indices.sorted { a, b in
            switch (upcoming(entries[a]), upcoming(entries[b])) {
            case let (x?, y?) where x != y: return x < y
            case (.some, nil): return true
            case (nil, .some): return false
            default: return entries[a].createdAt > entries[b].createdAt
            }
        }

        var seen = Set<String>()
        return sorted.filter { seen.insert(entries[$0].raw).inserted }
    }

    /// `records` in shelf order.
    static func arrange(_ records: [ScanRecord], now: Date = .now, calendar: Calendar = .current) -> [ScanRecord] {
        let entries = records.map { record in
            Entry(raw: record.raw, createdAt: record.createdAt, tripDate: record.tripDate(near: now, calendar: calendar))
        }
        return order(entries, now: now, calendar: calendar).map { records[$0] }
    }
}

extension ScanRecord {
    /// The flight day of a saved boarding pass.
    @MainActor func tripDate(near reference: Date = .now, calendar: Calendar = .current) -> Date? {
        guard kind == .travel, case .travel(let pass) = PayloadParser.parse(raw, symbology: symbology) else { return nil }
        return pass.date(near: reference, calendar: calendar)
    }
}
