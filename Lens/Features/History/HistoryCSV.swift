import CoreTransferable
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// RFC 4180 CSV of History: date, kind, format, content, title, place.
nonisolated enum HistoryCSV {
    struct Row: Sendable, Equatable {
        var date: Date
        var kind: String
        var format: String
        var content: String
        var title: String
        var place: String
    }

    static let header = ["Date", "Kind", "Format", "Content", "Title", "Place"]

    static func document(_ rows: [Row]) -> String {
        let dateStyle = Date.ISO8601FormatStyle(timeZone: .current)
        let lines = [header] + rows.map { row in
            [row.date.formatted(dateStyle), row.kind, row.format, row.content, row.title, row.place]
        }
        return lines.map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    /// Quotes a field when it contains a delimiter, quote or line break; doubles embedded quotes.
    /// Fields starting with `=` or `@` get a leading apostrophe so spreadsheets don't evaluate them.
    static func escape(_ field: String) -> String {
        var value = field
        if let first = value.first, first == "=" || first == "@" { value = "'" + value }
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

extension HistoryCSV.Row {
    init(_ record: ScanRecord) {
        self.init(
            date: record.createdAt,
            kind: String(localized: record.kind.title),
            format: record.symbology.displayName,
            content: record.raw,
            title: record.title,
            place: record.placeName ?? ""
        )
    }
}

/// A CSV file of History, built only when the user actually shares it.
nonisolated struct HistoryExport: Transferable {
    let container: ModelContainer
    /// Limit to these record ids; `nil` exports everything.
    var ids: Set<UUID>?

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { export in
            let rows = await export.rows()
            let url = URL.temporaryDirectory.appending(path: String(localized: "Lunet History") + ".csv")
            try Data(HistoryCSV.document(rows).utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }

    @MainActor
    private func rows() -> [HistoryCSV.Row] {
        let descriptor = FetchDescriptor<ScanRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let records = (try? container.mainContext.fetch(descriptor)) ?? []
        return records.filter { ids?.contains($0.id) ?? true }.map(HistoryCSV.Row.init)
    }
}
