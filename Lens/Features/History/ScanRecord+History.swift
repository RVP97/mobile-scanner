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

    var isVerifiedSafe: Bool { safetyLevel == .safe }

    /// The stored safety verdict for links, if one was reached.
    var safetyLevel: SafetyVerdict.Level? { safetyRaw.flatMap(SafetyVerdict.Level.init(rawValue:)) }

    /// A link Lens warned about: shown with its caution state everywhere it's listed.
    var isFlagged: Bool { safetyLevel == .caution || safetyLevel == .danger }
}
