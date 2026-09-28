import Foundation

/// What the person wants to share, chosen before anything about formats.
enum CreateIntent: String, CaseIterable, Identifiable, Hashable {
    case link, wifi, contact, text, email, sms, phone, event, location, product

    var id: String { rawValue }

    var kind: CodeKind {
        switch self {
        case .link: .link
        case .wifi: .wifi
        case .contact: .contact
        case .text: .text
        case .email: .email
        case .sms: .sms
        case .phone: .phone
        case .event: .event
        case .location: .location
        case .product: .product
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .wifi: "Wi-Fi Network"
        case .product: "Product Barcode"
        default: kind.title
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .link: "Open a website"
        case .wifi: "Join without typing a password"
        case .contact: "Share a contact card"
        case .text: "Show a note or message"
        case .email: "Start an email"
        case .sms: "Start a text message"
        case .phone: "Call a number"
        case .event: "Add to Calendar"
        case .location: "Open a place in Maps"
        case .product: "EAN or UPC for retail"
        }
    }

    /// Formats that make sense for this content, default first.
    var formats: [Symbology] {
        self == .product ? [.ean13, .upcA, .ean8, .upcE] : [.qr, .aztec, .pdf417, .dataMatrix]
    }
}

/// A finished, encodable piece of content: what the studio styles and what History stores.
struct CodeDocument: Hashable {
    var raw: String
    var symbology: Symbology
    var payload: Payload
    /// Short human name ("Casa Chen", "atlas-coffee.co").
    var title: String
    /// Default frame caption ("Scan to join Casa Chen").
    var caption: String

    var kind: CodeKind { payload.kind }

    var scanResult: ScanResult {
        ScanResult(code: ScannedCode(raw: raw, symbology: symbology), payload: payload)
    }
}
