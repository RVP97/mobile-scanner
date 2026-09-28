import CryptoKit
import Foundation

/// Reads the on-disk store of @react-native-async-storage on iOS: a `manifest.json` of
/// key → value, where values of about 1 KB or more are `null` and live in a sibling file
/// named after the MD5 of the key.
struct AsyncStorageReader {
    static let folderName = "RCTAsyncLocalStorage_V1"

    let directory: URL

    /// Where the old app kept its store: newer versions under Application Support/<bundle id>,
    /// older ones under Documents.
    static func candidateDirectories(bundleID: String = Bundle.main.bundleIdentifier ?? "com.rvp97.scanner") -> [URL] {
        [
            URL.applicationSupportDirectory.appending(path: bundleID).appending(path: folderName),
            URL.documentsDirectory.appending(path: folderName),
        ]
    }

    static func locate(in directories: [URL] = candidateDirectories()) -> AsyncStorageReader? {
        directories
            .first { FileManager.default.fileExists(atPath: $0.appending(path: "manifest.json").path(percentEncoded: false)) }
            .map(AsyncStorageReader.init(directory:))
    }

    func value(forKey key: String) -> String? {
        guard let data = try? Data(contentsOf: directory.appending(path: "manifest.json")),
              let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entry = manifest[key]
        else { return nil }
        if let inline = entry as? String { return inline }
        return try? String(contentsOf: directory.appending(path: Self.md5(key)), encoding: .utf8)
    }

    static func md5(_ key: String) -> String {
        Insecure.MD5.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
