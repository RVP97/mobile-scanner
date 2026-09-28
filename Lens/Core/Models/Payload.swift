import Foundation

/// A decoded code, straight off the camera or out of a photo.
struct ScannedCode: Hashable, Sendable {
    var raw: String
    var symbology: Symbology
    /// Corner points in the preview layer's coordinate space (clockwise from top-left), if known.
    var corners: [CGPoint] = []
}

/// The structured meaning of a code's text. `PayloadParser` produces it; the result
/// screen, history rows and the creator all speak it.
enum Payload: Hashable, Sendable {
    case link(URL)
    case wifi(WiFiNetwork)
    case product(gtin: String)
    case contact(ContactCard)
    case event(CalendarEvent)
    case email(EmailMessage)
    case sms(SMSMessage)
    case phone(String)
    case location(GeoPoint)
    case travel(BoardingPass)
    case crypto(CryptoRequest)
    case shipment(String)
    case text(String)

    var kind: CodeKind {
        switch self {
        case .link: .link
        case .wifi: .wifi
        case .product: .product
        case .contact: .contact
        case .event: .event
        case .email: .email
        case .sms: .sms
        case .phone: .phone
        case .location: .location
        case .travel: .travel
        case .crypto: .crypto
        case .shipment: .shipment
        case .text: .text
        }
    }
}

struct WiFiNetwork: Hashable, Codable, Sendable {
    enum Security: String, Codable, CaseIterable, Sendable {
        case wpa = "WPA"      // WPA/WPA2/WPA3 personal
        case wep = "WEP"
        case open = "nopass"
    }
    var ssid: String
    var password: String
    var security: Security = .wpa
    var isHidden: Bool = false
}

struct ContactCard: Hashable, Codable, Sendable {
    var givenName: String = ""
    var familyName: String = ""
    var organization: String = ""
    var jobTitle: String = ""
    var phones: [String] = []
    var emails: [String] = []
    var urls: [String] = []
    var address: String = ""
    var note: String = ""

    var fullName: String {
        [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

struct CalendarEvent: Hashable, Codable, Sendable {
    var title: String
    var start: Date?
    var end: Date?
    var isAllDay: Bool = false
    var location: String = ""
    var notes: String = ""
}

struct EmailMessage: Hashable, Codable, Sendable {
    var to: String
    var subject: String = ""
    var body: String = ""
}

struct SMSMessage: Hashable, Codable, Sendable {
    var number: String
    var body: String = ""
}

struct GeoPoint: Hashable, Codable, Sendable {
    var latitude: Double
    var longitude: Double
    var label: String = ""
}

/// IATA Bar Coded Boarding Pass (Resolution 792), first leg.
struct BoardingPass: Hashable, Codable, Sendable {
    var passengerName: String
    var bookingReference: String
    var from: String
    var to: String
    var carrier: String
    var flightNumber: String
    /// Julian day of year from the pass; resolved to a date near today when displayed.
    var dayOfYear: Int
    var cabin: String
    var seat: String
    var sequence: String
}

struct CryptoRequest: Hashable, Codable, Sendable {
    var scheme: String        // bitcoin, ethereum, lightning, …
    var address: String
    var amount: String = ""
    var label: String = ""
}
