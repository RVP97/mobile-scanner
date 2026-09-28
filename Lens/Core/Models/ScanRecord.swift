import Foundation
import SwiftData

/// One row in History: something scanned, or something made in the creator.
@Model
final class ScanRecord {
    enum Origin: String, Codable { case scanned, created }

    var id: UUID = UUID()
    var raw: String = ""
    var symbologyRaw: String = Symbology.qr.rawValue
    var kindRaw: String = CodeKind.text.rawValue
    var originRaw: String = Origin.scanned.rawValue
    /// Human title shown in lists ("Menu — Atlas Coffee", "Atlas Guest", "Maya Chen").
    var title: String = ""
    /// Secondary line (domain, symbology, product maker…).
    var subtitle: String = ""
    var createdAt: Date = Date.now
    var isPinned: Bool = false
    var placeName: String?
    var latitude: Double?
    var longitude: Double?
    /// `SafetyVerdict.Level` raw value for links, when a check ran.
    var safetyRaw: String?
    /// Encoded `CodeStyle` for created codes.
    var styleData: Data?

    init(
        raw: String,
        symbology: Symbology,
        kind: CodeKind,
        origin: Origin = .scanned,
        title: String,
        subtitle: String = "",
        createdAt: Date = .now
    ) {
        self.raw = raw
        self.symbologyRaw = symbology.rawValue
        self.kindRaw = kind.rawValue
        self.originRaw = origin.rawValue
        self.title = title
        self.subtitle = subtitle
        self.createdAt = createdAt
    }

    var symbology: Symbology { Symbology(rawValue: symbologyRaw) ?? .qr }
    var kind: CodeKind { CodeKind(rawValue: kindRaw) ?? .text }
    var origin: Origin { Origin(rawValue: originRaw) ?? .scanned }
}
