import Foundation
import SQLite3
import Testing
@testable import Lens

struct HistoryLegacyImportTests {
    static let scanHistory = """
    [
      {"id":"scan_1727530000000","data":"https://atlas-coffee.co/menu","type":"qr","timestamp":1727530000000,"formattedDate":"9/28/2024, 9:41:00 AM"},
      {"id":"scan_1727520000000","data":"4006381333931","type":"org.gs1.EAN-13","timestamp":1727520000000,"formattedDate":"x"},
      {"id":"scan_3","data":"SHIP-88213-XK","type":"code128","timestamp":1727510000000,"formattedDate":"x"},
      {"id":"scan_4","data":"036000291452","type":"upc_a","timestamp":1727500000000,"formattedDate":"x"},
      {"id":"broken","type":"qr"},
      {"id":"scan_5","data":"Locker 214","type":"org.iso.QRCode","timestamp":1727490000000,"formattedDate":"x"}
    ]
    """

    static let generationHistory = """
    [
      {"id":"gen_1","data":"Studio Norte","format":"qr","formatName":"QR Code","timestamp":1727480000000,"formattedDate":"x"},
      {"id":"gen_2","data":"12345670","format":"EAN8","formatName":"EAN-8","timestamp":1727470000000,"formattedDate":"x"},
      {"id":"gen_3","data":"01234565","format":"UPCE","formatName":"UPC-E","timestamp":1727460000000,"formattedDate":"x"}
    ]
    """

    @Test func scannedItemsMapTypeAndTime() {
        let entries = LegacyImporter.scannedEntries(from: Self.scanHistory)
        #expect(entries.count == 5)
        #expect(entries.map(\.symbology) == [.qr, .ean13, .code128, .upcA, .qr])
        #expect(entries.allSatisfy { $0.origin == .scanned })
        #expect(entries[0].date == Date(timeIntervalSince1970: 1_727_530_000))
    }

    @Test func createdItemsMapGeneratorFormats() {
        let entries = LegacyImporter.createdEntries(from: Self.generationHistory)
        #expect(entries.map(\.symbology) == [.qr, .ean8, .upcE])
        #expect(entries.allSatisfy { $0.origin == .created })
    }

    @Test(arguments: [
        ("qr", Symbology.qr), ("org.iso.QRCode", .qr), ("ean13", .ean13), ("org.gs1.EAN-13", .ean13),
        ("EAN13", .ean13), ("ean8", .ean8), ("org.gs1.EAN-8", .ean8), ("UPC", .upcA), ("upc_e", .upcE),
        ("org.gs1.UPC-E", .upcE), ("CODE128", .code128), ("org.iso.Code128", .code128),
        ("org.iso.Code39Mod43", .code39), ("com.intermec.Code93", .code93), ("itf14", .itf14),
        ("org.ansi.Interleaved2of5", .itf), ("ITF", .itf), ("datamatrix", .dataMatrix),
        ("org.iso.DataMatrix", .dataMatrix), ("pdf417", .pdf417), ("org.iso.Aztec", .aztec),
        ("codabar", .codabar), ("MSI", .msi), ("pharmacode", .pharmacode),
        ("org.gs1.GS1DataBarExpanded", .gs1DataBar), ("unknown", .qr),
    ])
    func legacyTypeStrings(type: String, expected: Symbology) {
        #expect(LegacyImporter.symbology(forLegacyType: type) == expected)
    }

    @Test func recordsUseParsedKind() {
        let entry = LegacyImporter.Entry(raw: "https://atlas-coffee.co/menu", symbology: .qr, origin: .scanned, date: .now)
        let record = LegacyImporter.record(for: entry)
        #expect(record.kind == .link)
        #expect(record.origin == .scanned)
    }

    @Test func malformedJSONImportsNothing() {
        #expect(LegacyImporter.scannedEntries(from: "{not json").isEmpty)
        #expect(LegacyImporter.scannedEntries(from: nil).isEmpty)
    }

    @Test func readsInlineAndSpilledAsyncStorageValues() throws {
        let folder = URL.temporaryDirectory.appending(path: "legacy-\(UUID())").appending(path: AsyncStorageReader.folderName)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }

        let manifest: [String: Any] = ["generationHistory": Self.generationHistory, "scanHistory": NSNull()]
        try JSONSerialization.data(withJSONObject: manifest).write(to: folder.appending(path: "manifest.json"))
        try Data(Self.scanHistory.utf8).write(to: folder.appending(path: AsyncStorageReader.md5("scanHistory")))

        let reader = try #require(AsyncStorageReader.locate(in: [URL.temporaryDirectory.appending(path: "missing"), folder]))
        #expect(reader.value(forKey: "generationHistory") == Self.generationHistory)
        #expect(reader.value(forKey: "scanHistory") == Self.scanHistory)
        #expect(reader.value(forKey: "nope") == nil)
    }

    @Test func md5MatchesReactNative() {
        #expect(AsyncStorageReader.md5("scanHistory") == "df29ccd19a65779df5e41e0607e85f44")
        #expect(AsyncStorageReader.md5("") == "d41d8cd98f00b204e9800998ecf8427e")
    }

    @Test func migratesSettingsFromSQLite() throws {
        let url = URL.temporaryDirectory.appending(path: "ExpoSQLiteStorage-\(UUID())")
        defer { try? FileManager.default.removeItem(at: url) }
        var db: OpaquePointer?
        #expect(sqlite3_open(url.path(percentEncoded: false), &db) == SQLITE_OK)
        sqlite3_exec(db, """
            CREATE TABLE storage (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);
            INSERT INTO storage VALUES ('hapticEnabled', 'false'), ('autoOpenUrl', 'true'),
              ('requireAuthForHistory', 'true'), ('hasSeenWelcome', 'true'), ('soundEnabled', 'false');
            """, nil, nil, nil)
        sqlite3_close(db)

        let values = LegacySettings.readKeyValues(at: url)
        #expect(values["hapticEnabled"] == "false")

        let defaults = UserDefaults(suiteName: "HistoryLegacyImportTests-\(UUID())")!
        defaults.set(true, forKey: Pref.sound)  // already chosen in Lens: must win
        LegacySettings.apply(values, to: defaults)
        #expect(defaults.object(forKey: Pref.haptics) as? Bool == false)
        #expect(defaults.object(forKey: Pref.scanAndGo) as? Bool == true)
        #expect(defaults.object(forKey: Pref.requireFaceID) as? Bool == true)
        #expect(defaults.object(forKey: Pref.sound) as? Bool == true)
        #expect(defaults.object(forKey: Pref.multiScan) == nil)
    }
}
