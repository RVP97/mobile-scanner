import Foundation

// OWNER: Result module. Keep these signatures stable; other modules call them.
enum PayloadParser {
    static func parse(_ raw: String, symbology: Symbology) -> Payload {
        let text = raw.trimmed
        guard !text.isEmpty else { return .text(raw) }

        if let payload = parseScheme(text) { return payload }
        if let pass = BoardingPassParser.parse(raw) { return .travel(pass) }
        if let gtin = retailNumber(text, symbology: symbology) { return .product(gtin: gtin) }
        if let shipment = ShipmentCarrier.detect(text, symbology: symbology) { return .shipment(shipment.number) }
        if let request = CryptoParser.parseBareAddress(text) { return .crypto(request) }
        if let email = MessageParsers.bareEmail(text) { return .email(email) }
        if let url = LinkParser.bareDomain(text) { return .link(url) }
        return .text(raw)
    }

    /// Payloads announced by a scheme or header, checked case-insensitively.
    private static func parseScheme(_ text: String) -> Payload? {
        if text.hasPrefixIgnoringCase("WIFI:") { return WiFiParser.parse(text).map(Payload.wifi) }
        if text.hasPrefixIgnoringCase("BEGIN:VCARD") { return ContactParser.parseVCard(text).map(Payload.contact) }
        if text.hasPrefixIgnoringCase("MECARD:") { return ContactParser.parseMeCard(text).map(Payload.contact) }
        if text.hasPrefixIgnoringCase("BEGIN:VCALENDAR") || text.hasPrefixIgnoringCase("BEGIN:VEVENT") {
            return EventParser.parse(text).map(Payload.event)
        }
        if let email = MessageParsers.mailto(text) ?? MessageParsers.matmsg(text) { return .email(email) }
        if let sms = MessageParsers.sms(text) { return .sms(sms) }
        if let number = MessageParsers.tel(text) { return .phone(number) }
        if let point = MessageParsers.geo(text) { return .location(point) }
        if let request = CryptoParser.parseURI(text) { return .crypto(request) }
        if let url = LinkParser.parse(text) { return .link(url) }
        return nil
    }

    /// Retail symbologies are always products (even with a bad check digit, which the result flags).
    /// Other formats only count when the number is a valid GTIN, or a GS1 element string with AI (01).
    private static func retailNumber(_ text: String, symbology: Symbology) -> String? {
        let digits = text.filter { !$0.isWhitespace && $0 != "-" }
        if symbology.isRetail, digits.isAllDigits { return GTIN.normalize(digits, symbology: symbology) }

        if [.gs1DataBar, .dataMatrix, .code128].contains(symbology),
           let match = text.prefixMatch(of: /(?:\]d2|\]C1|\]e0)?\(?01\)?(\d{14})/),
           GTIN.hasValidCheckDigit(String(match.1)),
           text.count > 14 {
            return GTIN.normalize(String(match.1), symbology: symbology)
        }

        guard digits.isAllDigits, digits.count == text.count else { return nil }
        let allowed: Set<Int> = symbology.isTwoDimensional ? [12, 13] : GTIN.lengths
        guard allowed.contains(digits.count), GTIN.hasValidCheckDigit(digits) else { return nil }
        return GTIN.normalize(digits, symbology: symbology)
    }
}

extension Payload {
    /// Primary line for lists and headers ("atlas-coffee.co", "Atlas Guest").
    var displayTitle: String {
        switch self {
        case .link(let url):
            return url.displayHost ?? String(url.absoluteString.prefix(80))
        case .wifi(let network):
            return network.ssid
        case .product(let gtin):
            return GTIN.grouped(gtin)
        case .contact(let card):
            return card.displayName
        case .event(let event):
            return event.title.isEmpty ? String(localized: "Event") : event.title
        case .email(let message):
            return message.to.isEmpty ? String(localized: "New email") : message.to
        case .sms(let message):
            return message.number.isEmpty ? String(localized: "New message") : message.number
        case .phone(let number):
            return number
        case .location(let point):
            return point.label.isEmpty ? point.coordinateText : point.label
        case .travel(let pass):
            return "\(pass.from) → \(pass.to) · \(pass.flightDesignator)"
        case .crypto(let request):
            return request.shortAddress
        case .shipment(let number):
            return number
        case .text(let text):
            let firstLine = text.trimmed.split(separator: "\n").first.map(String.init) ?? text
            return firstLine.count > 80 ? String(firstLine.prefix(79)) + "…" : firstLine
        }
    }

    /// Secondary line for lists.
    var displaySubtitle: String {
        switch self {
        case .link(let url):
            return url.displayPath ?? String(localized: "Website")
        case .wifi(let network):
            return network.securityDescription
        case .product(let gtin):
            return [GTIN.formatName(gtin), GTIN.prefixRegion(gtin)].compactMap(\.self).joined(separator: " · ")
        case .contact(let card):
            let role = [card.jobTitle, card.organization].filter { !$0.isEmpty }.joined(separator: " · ")
            if !role.isEmpty, role != card.displayName { return role }
            return card.phones.first ?? card.emails.first ?? ""
        case .event(let event):
            return [event.dateSummary, event.location].filter { !$0.isEmpty }.joined(separator: " · ")
        case .email(let message):
            return message.subject
        case .sms(let message):
            return message.body
        case .phone:
            return String(localized: "Phone number")
        case .location(let point):
            return point.label.isEmpty ? String(localized: "Map location") : point.coordinateText
        case .travel(let pass):
            let seat = pass.seat.isEmpty ? nil : String(localized: "Seat \(pass.seat)")
            return [pass.displayName, seat].compactMap(\.self).joined(separator: " · ")
        case .crypto(let request):
            if !request.amount.isEmpty { return "\(request.networkName) · \(request.amount) \(request.currencyCode)" }
            return request.label.isEmpty ? request.networkName : "\(request.networkName) · \(request.label)"
        case .shipment(let number):
            return ShipmentCarrier.carrier(forTrackingNumber: number).map { String(localized: "\($0.name) package") }
                ?? String(localized: "Tracking number")
        case .text(let text):
            return String(localized: "\(text.count) characters")
        }
    }
}

// MARK: - Display helpers

extension URL {
    /// Host without a leading `www.` ("atlas-coffee.co").
    var displayHost: String? {
        guard let host = host(percentEncoded: false), !host.isEmpty else { return nil }
        let decoded = Punycode.decodeHost(host)
        return decoded.hasPrefix("www.") ? String(decoded.dropFirst(4)) : decoded
    }

    /// Path and query when they say something ("/menu"), nil for a bare homepage.
    var displayPath: String? {
        var path = path(percentEncoded: false)
        if let query = query(percentEncoded: false), !query.isEmpty { path += "?" + query }
        guard path.count > 1 else { return nil }
        return path.count > 60 ? String(path.prefix(59)) + "…" : path
    }
}

extension WiFiNetwork {
    var securityDescription: String {
        switch security {
        case .wpa: String(localized: "WPA · Secured")
        case .wep: String(localized: "WEP · Weak security")
        case .open: String(localized: "Open network")
        }
    }
}

extension ContactCard {
    /// Full name, else company, else first email or phone.
    var displayName: String {
        if !fullName.isEmpty { return fullName }
        if !organization.isEmpty { return organization }
        return emails.first ?? phones.first ?? String(localized: "Contact")
    }

    /// "MC".
    var initials: String {
        let letters = [givenName, familyName].compactMap(\.first)
        if !letters.isEmpty { return String(letters.prefix(2)).uppercased() }
        return displayName.first.map { String($0).uppercased() } ?? ""
    }
}

extension CalendarEvent {
    /// "Thu, Oct 1, 7:35 PM" or "Thu, Oct 1" for all-day events.
    var dateSummary: String {
        guard let start else { return "" }
        if isAllDay { return start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) }
        return start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
    }

    /// The last day of an all-day event (iCalendar's DTEND is exclusive).
    var inclusiveEnd: Date? {
        guard let end else { return nil }
        guard isAllDay else { return end }
        return Calendar.current.date(byAdding: .day, value: -1, to: end).map { max($0, start ?? $0) }
    }
}

extension GeoPoint {
    /// Coordinates are 0,0 when a `geo:` URI only carried a place name to search for.
    var hasCoordinates: Bool { latitude != 0 || longitude != 0 }

    /// "19.4326° N, 99.1332° W".
    var coordinateText: String {
        let lat = abs(latitude).formatted(.number.precision(.fractionLength(0...4)))
        let lon = abs(longitude).formatted(.number.precision(.fractionLength(0...4)))
        return "\(lat)° \(latitude >= 0 ? "N" : "S"), \(lon)° \(longitude >= 0 ? "E" : "W")"
    }
}

extension ShipmentCarrier {
    /// Carrier for a number `PayloadParser` already recognised as a tracking number.
    static func carrier(forTrackingNumber number: String) -> ShipmentCarrier? {
        detect(number, symbology: .code128)?.carrier
    }
}
