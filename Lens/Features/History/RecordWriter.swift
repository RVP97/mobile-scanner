import SwiftData
import Foundation

// OWNER: History module. Scanner and Create call this to persist a code. Keep signature stable.
enum RecordWriter {
    @discardableResult
    static func save(_ result: ScanResult, origin: ScanRecord.Origin = .scanned, style: Data? = nil, in context: ModelContext) -> ScanRecord? {
        guard Pref.bool(Pref.saveHistory, default: Pref.Default.saveHistory) || origin == .created else { return nil }
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
        context.insert(record)
        return record
    }
}
