import SwiftUI

/// What a code *means*, independent of how it's printed. Drives the result screen,
/// the glyph tile and the tint used everywhere the code appears.
enum CodeKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case link
    case wifi
    case product
    case contact
    case event
    case email
    case sms
    case phone
    case location
    case travel
    case crypto
    case shipment
    case text

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .link: "Link"
        case .wifi: "Wi-Fi"
        case .product: "Product"
        case .contact: "Contact"
        case .event: "Event"
        case .email: "Email"
        case .sms: "Message"
        case .phone: "Phone"
        case .location: "Location"
        case .travel: "Boarding pass"
        case .crypto: "Crypto address"
        case .shipment: "Shipment"
        case .text: "Text"
        }
    }

    /// SF Symbol used in the kind tile.
    var symbol: String {
        switch self {
        case .link: "link"
        case .wifi: "wifi"
        case .product: "barcode"
        case .contact: "person.crop.circle"
        case .event: "calendar"
        case .email: "envelope"
        case .sms: "message"
        case .phone: "phone"
        case .location: "mappin.and.ellipse"
        case .travel: "airplane"
        case .crypto: "bitcoinsign.circle"
        case .shipment: "shippingbox"
        case .text: "text.alignleft"
        }
    }

    var tint: Color { Palette.tint(for: self) }

    /// Filter chips shown in History, in display order.
    static let historyFilters: [CodeKind] = [.link, .wifi, .product, .contact, .travel, .event, .text]
}
