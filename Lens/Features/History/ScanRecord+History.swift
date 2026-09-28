import Foundation

extension ScanRecord {
    /// Rebuilds the result screen's model from a stored row.
    @MainActor var scanResult: ScanResult {
        ScanResult(
            code: ScannedCode(raw: raw, symbology: symbology),
            payload: PayloadParser.parse(raw, symbology: symbology),
            scannedAt: createdAt,
            placeName: placeName
        )
    }

    /// The row's headline, falling back to the raw text for untitled records.
    var historyTitle: String { title.isEmpty ? raw : title }

    var isVerifiedSafe: Bool { safetyRaw == SafetyVerdict.Level.safe.rawValue }
}
