import Foundation
import SwiftData

/// Brings History and settings over from the previous (React Native) version of the app, which
/// shares this bundle id and container. Runs once; safe to call on every launch.
enum LegacyImporter {
    static let doneKey = "legacyImportDone"

    /// One history item from the old app.
    struct Entry: Equatable {
        var raw: String
        var symbology: Symbology
        var origin: ScanRecord.Origin
        var date: Date
    }

    static func runIfNeeded(into context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: doneKey) else { return }
        defer { defaults.set(true, forKey: doneKey) }

        if let storage = AsyncStorageReader.locate() {
            let entries = scannedEntries(from: storage.value(forKey: "scanHistory"))
                + createdEntries(from: storage.value(forKey: "generationHistory"))
            entries.map(record(for:)).forEach(context.insert)
            if !entries.isEmpty { try? context.save() }
        }
        LegacySettings.migrate(into: defaults)
    }

    // MARK: Parsing

    private struct LegacyItem: Decodable {
        var data: String
        var type: String?
        var format: String?
        var timestamp: Double?
    }

    /// `scanHistory`: `[{id, data, type, timestamp (ms), formattedDate}]`.
    static func scannedEntries(from json: String?) -> [Entry] {
        items(from: json).map {
            Entry(raw: $0.data, symbology: symbology(forLegacyType: $0.type ?? ""), origin: .scanned, date: date($0.timestamp))
        }
    }

    /// `generationHistory`: `[{id, data, format, formatName, timestamp (ms), formattedDate}]`.
    static func createdEntries(from json: String?) -> [Entry] {
        items(from: json).map {
            Entry(raw: $0.data, symbology: symbology(forLegacyType: $0.format ?? ""), origin: .created, date: date($0.timestamp))
        }
    }

    private static func items(from json: String?) -> [LegacyItem] {
        guard let data = json?.data(using: .utf8),
              let items = try? JSONDecoder().decode([Failable<LegacyItem>].self, from: data)
        else { return [] }
        return items.compactMap(\.value).filter { !$0.data.isEmpty }
    }

    private static func date(_ milliseconds: Double?) -> Date {
        milliseconds.map { Date(timeIntervalSince1970: $0 / 1000) } ?? .now
    }

    /// Maps the old app's format strings — expo-camera names ("qr", "ean13", "upc_a"), iOS
    /// metadata types ("org.iso.QRCode", "org.gs1.EAN-13") and generator formats ("CODE128", "UPC").
    static func symbology(forLegacyType type: String) -> Symbology {
        var name = type.lowercased()
        for prefix in ["org.iso.", "org.gs1.", "org.ansi.", "com.intermec.", "com.apple."] where name.hasPrefix(prefix) {
            name.removeFirst(prefix.count)
        }
        name = name.filter { $0.isLetter || $0.isNumber }
        switch name {
        case "qr", "qrcode": return .qr
        case "microqr", "microqrcode": return .microQR
        case "aztec": return .aztec
        case "datamatrix": return .dataMatrix
        case "pdf417": return .pdf417
        case "micropdf417": return .microPDF417
        case "ean13": return .ean13
        case "ean8": return .ean8
        case "upc", "upca": return .upcA
        case "upce": return .upcE
        case "code128": return .code128
        case "code39", "code39mod43": return .code39
        case "code93": return .code93
        case "itf14": return .itf14
        case "itf", "interleaved2of5", "i2of5": return .itf
        case "codabar": return .codabar
        case "msi": return .msi
        case "pharmacode": return .pharmacode
        case _ where name.hasPrefix("gs1databar"): return .gs1DataBar
        default: return .qr
        }
    }

    static func record(for entry: Entry) -> ScanRecord {
        let payload = PayloadParser.parse(entry.raw, symbology: entry.symbology)
        return ScanRecord(
            raw: entry.raw,
            symbology: entry.symbology,
            kind: payload.kind,
            origin: entry.origin,
            title: payload.displayTitle,
            subtitle: payload.displaySubtitle,
            createdAt: entry.date
        )
    }
}

/// Decodes an element if it can, so one malformed item doesn't lose the whole history.
private struct Failable<Wrapped: Decodable>: Decodable {
    var value: Wrapped?
    init(from decoder: Decoder) throws {
        value = try? Wrapped(from: decoder)
    }
}
