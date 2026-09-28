import Foundation
import SQLite3

/// Moves the old app's toggles (kept by expo-sqlite's localStorage in a key/value SQLite table)
/// into Lens preferences. Anything already set in Lens wins; a missing database is fine.
enum LegacySettings {
    /// Old localStorage key → Lens `Pref` key.
    static let keyMap: [String: String] = [
        "hapticEnabled": Pref.haptics,
        "soundEnabled": Pref.sound,
        "autoCopy": Pref.autoCopy,
        "autoOpenUrl": Pref.scanAndGo,
        "multiScan": Pref.multiScan,
        "saveHistory": Pref.saveHistory,
        "requireAuthForHistory": Pref.requireFaceID,
    ]

    static func migrate(into defaults: UserDefaults) {
        for database in candidateDatabases() {
            let values = readKeyValues(at: database)
            if !values.isEmpty {
                apply(values, to: defaults)
                return
            }
        }
    }

    /// Applies JSON-encoded legacy values ("true" / "false") for the keys Lens understands.
    static func apply(_ values: [String: String], to defaults: UserDefaults) {
        for (legacyKey, prefKey) in keyMap {
            guard defaults.object(forKey: prefKey) == nil,
                  let json = values[legacyKey]?.data(using: .utf8),
                  let flag = try? JSONSerialization.jsonObject(with: json, options: .fragmentsAllowed) as? Bool
            else { continue }
            defaults.set(flag, forKey: prefKey)
        }
    }

    // MARK: Finding the database

    /// expo-sqlite keeps databases in Documents/SQLite; its localStorage one is "ExpoSQLiteStorage".
    static func candidateDatabases(fileManager: FileManager = .default) -> [URL] {
        var found: [URL] = []
        let sqliteFolder = URL.documentsDirectory.appending(path: "SQLite")
        if let files = try? fileManager.contentsOfDirectory(at: sqliteFolder, includingPropertiesForKeys: nil) {
            let isExpoStorage = { (url: URL) in url.lastPathComponent.hasPrefix("ExpoSQLiteStorage") }
            let databases = files.filter(isDatabaseFile)
            found += databases.filter(isExpoStorage) + databases.filter { !isExpoStorage($0) }
        }
        for root in [URL.documentsDirectory, URL.libraryDirectory] {
            let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants])
            while let url = enumerator?.nextObject() as? URL {
                if enumerator?.level ?? 0 > 4 { enumerator?.skipDescendants() }
                if url.lastPathComponent.hasPrefix("ExpoSQLiteStorage"), isDatabaseFile(url), !found.contains(url) {
                    found.append(url)
                }
            }
        }
        return found
    }

    private static func isDatabaseFile(_ url: URL) -> Bool {
        !["-wal", "-shm", "-journal"].contains { url.lastPathComponent.hasSuffix($0) } && !url.hasDirectoryPath
    }

    // MARK: Reading

    /// Every row of the first table that has `key` and `value` columns. Opened read-only.
    static func readKeyValues(at url: URL) -> [String: String] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path(percentEncoded: false), &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return [:]
        }
        defer { sqlite3_close(db) }

        for table in strings(db, "SELECT name FROM sqlite_master WHERE type = 'table'") {
            let columns = Set(strings(db, "PRAGMA table_info(\"\(table.replacingOccurrences(of: "\"", with: "\"\""))\")", column: 1))
            guard columns.contains("key"), columns.contains("value") else { continue }
            let quoted = table.replacingOccurrences(of: "\"", with: "\"\"")
            return pairs(db, "SELECT key, value FROM \"\(quoted)\"")
        }
        return [:]
    }

    private static func strings(_ db: OpaquePointer?, _ sql: String, column: Int32 = 0) -> [String] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        var result: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let text = sqlite3_column_text(statement, column) { result.append(String(cString: text)) }
        }
        return result
    }

    private static func pairs(_ db: OpaquePointer?, _ sql: String) -> [String: String] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(statement) }
        var result: [String: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let key = sqlite3_column_text(statement, 0), let value = sqlite3_column_text(statement, 1) else { continue }
            result[String(cString: key)] = String(cString: value)
        }
        return result
    }
}
