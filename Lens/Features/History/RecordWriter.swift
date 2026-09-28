import Foundation
import SwiftData

/// Persists scans and created codes. Scanner and Create call this; keep `save`'s signature stable.
enum RecordWriter {
    /// Scanning the same code again within this window refreshes the existing row instead of adding one.
    static let dedupeWindow: TimeInterval = 10

    @discardableResult
    static func save(_ result: ScanResult, origin: ScanRecord.Origin = .scanned, style: Data? = nil, in context: ModelContext) -> ScanRecord? {
        save(result, origin: origin, style: style, in: context, defaults: .standard)
    }

    @discardableResult
    static func save(
        _ result: ScanResult,
        origin: ScanRecord.Origin,
        style: Data?,
        in context: ModelContext,
        defaults: UserDefaults
    ) -> ScanRecord? {
        if origin == .scanned {
            defaults.set(defaults.integer(forKey: Pref.successfulScans) + 1, forKey: Pref.successfulScans)
        }
        let saveHistory = defaults.object(forKey: Pref.saveHistory) as? Bool ?? Pref.Default.saveHistory
        guard saveHistory || origin == .created else { return nil }

        if let recent = recentDuplicate(of: result, origin: origin, in: context) {
            recent.createdAt = result.scannedAt
            if let style { recent.styleData = style }
            return recent
        }

        let record = ScanRecord(
            raw: result.code.raw,
            symbology: result.code.symbology,
            kind: result.payload.kind,
            origin: origin,
            title: result.payload.displayTitle,
            subtitle: result.payload.displaySubtitle,
            createdAt: result.scannedAt
        )
        record.styleData = style
        record.placeName = result.placeName
        context.insert(record)

        let rememberPlace = defaults.object(forKey: Pref.rememberPlace) as? Bool ?? Pref.Default.rememberPlace
        if origin == .scanned, rememberPlace, result.placeName == nil {
            Task { await LocationService.shared.stamp(record) }
        }
        return record
    }

    private static func recentDuplicate(of result: ScanResult, origin: ScanRecord.Origin, in context: ModelContext) -> ScanRecord? {
        let raw = result.code.raw
        let originRaw = origin.rawValue
        let cutoff = result.scannedAt.addingTimeInterval(-dedupeWindow)
        var descriptor = FetchDescriptor<ScanRecord>(
            predicate: #Predicate { $0.raw == raw && $0.originRaw == originRaw && $0.createdAt >= cutoff },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
