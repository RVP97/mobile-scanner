import Foundation

/// Turns structured content into the exact text a code carries, in the formats phone cameras
/// understand (ZXing Wi-Fi, vCard 3.0, iCalendar VEVENT, mailto/SMSTO/tel/geo URIs).
enum PayloadComposer {
    // MARK: Wi-Fi

    /// `WIFI:T:WPA;S:name;P:secret;H:true;;` with `\ ; , : "` escaped.
    static func wifi(_ network: WiFiNetwork) -> String {
        var fields = ["T:\(network.security.rawValue)", "S:\(escapeWiFi(network.ssid))"]
        if network.security != .open { fields.append("P:\(escapeWiFi(network.password))") }
        if network.isHidden { fields.append("H:true") }
        return "WIFI:" + fields.map { $0 + ";" }.joined() + ";"
    }

    static func escapeWiFi(_ value: String) -> String {
        var result = ""
        for character in value {
            if "\\;,:\"".contains(character) { result.append("\\") }
            result.append(character)
        }
        return result
    }

    // MARK: vCard 3.0

    static func vCard(_ card: ContactCard) -> String {
        var lines = ["BEGIN:VCARD", "VERSION:3.0"]
        lines.append("N:\(escapeText(card.familyName));\(escapeText(card.givenName));;;")
        let formatted = card.fullName.isEmpty ? card.organization : card.fullName
        lines.append("FN:\(escapeText(formatted))")
        if !card.organization.isEmpty { lines.append("ORG:\(escapeText(card.organization))") }
        if !card.jobTitle.isEmpty { lines.append("TITLE:\(escapeText(card.jobTitle))") }
        for phone in card.phones where !phone.isEmpty { lines.append("TEL;TYPE=CELL:\(escapeText(phone))") }
        for email in card.emails where !email.isEmpty { lines.append("EMAIL;TYPE=INTERNET:\(escapeText(email))") }
        for url in card.urls where !url.isEmpty { lines.append("URL:\(escapeText(url))") }
        if !card.address.isEmpty {
            // Single free-form address: street component only, lines kept as "\n".
            lines.append("ADR;TYPE=HOME:;;\(escapeText(card.address));;;;")
        }
        if !card.note.isEmpty { lines.append("NOTE:\(escapeText(card.note))") }
        lines.append("END:VCARD")
        return lines.joined(separator: "\r\n")
    }

    /// RFC 2426 / RFC 5545 TEXT escaping: backslash, semicolon, comma and newlines.
    static func escapeText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    // MARK: Event

    static func event(_ event: CalendarEvent, timeZone: TimeZone = .current) -> String {
        var lines = ["BEGIN:VEVENT", "SUMMARY:\(escapeText(event.title))"]
        if let start = event.start {
            if event.isAllDay {
                let end = event.end.map { max($0, start) } ?? start
                let dayAfterEnd = Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end
                lines.append("DTSTART;VALUE=DATE:\(dayStamp(start, timeZone: timeZone))")
                lines.append("DTEND;VALUE=DATE:\(dayStamp(dayAfterEnd, timeZone: timeZone))")
            } else {
                lines.append("DTSTART:\(utcStamp(start))")
                if let end = event.end { lines.append("DTEND:\(utcStamp(end))") }
            }
        }
        if !event.location.isEmpty { lines.append("LOCATION:\(escapeText(event.location))") }
        if !event.notes.isEmpty { lines.append("DESCRIPTION:\(escapeText(event.notes))") }
        lines.append("END:VEVENT")
        return lines.joined(separator: "\r\n")
    }

    static func utcStamp(_ date: Date) -> String {
        stamp(date, format: "yyyyMMdd'T'HHmmss'Z'", timeZone: TimeZone(identifier: "UTC")!)
    }

    static func dayStamp(_ date: Date, timeZone: TimeZone) -> String {
        stamp(date, format: "yyyyMMdd", timeZone: timeZone)
    }

    private static func stamp(_ date: Date, format: String, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    // MARK: URIs

    static func email(_ message: EmailMessage) -> String {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = message.to.trimmingCharacters(in: .whitespaces)
        var items: [URLQueryItem] = []
        if !message.subject.isEmpty { items.append(URLQueryItem(name: "subject", value: message.subject)) }
        if !message.body.isEmpty { items.append(URLQueryItem(name: "body", value: message.body)) }
        if !items.isEmpty {
            // Encode strictly so "&", "=" and "+" in the text survive every mail client.
            components.percentEncodedQueryItems = items.map {
                URLQueryItem(name: $0.name, value: $0.value?.addingPercentEncoding(withAllowedCharacters: .strictQueryValue))
            }
        }
        return components.string ?? "mailto:\(message.to)"
    }

    static func sms(_ message: SMSMessage) -> String {
        let number = dialable(message.number)
        return message.body.isEmpty ? "SMSTO:\(number)" : "SMSTO:\(number):\(message.body)"
    }

    static func phone(_ number: String) -> String { "tel:\(dialable(number))" }

    /// Keeps digits and a leading plus; drops spaces, dashes, dots and parentheses.
    static func dialable(_ number: String) -> String {
        let trimmed = number.trimmingCharacters(in: .whitespaces)
        let digits = trimmed.filter(\.isNumber)
        return trimmed.hasPrefix("+") ? "+" + digits : digits
    }

    static func location(_ point: GeoPoint) -> String {
        let coordinates = String(format: "%.6f,%.6f", locale: Locale(identifier: "en_US_POSIX"), point.latitude, point.longitude)
        let label = point.label.trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty, let encoded = label.addingPercentEncoding(withAllowedCharacters: .strictQueryValue) else {
            return "geo:\(coordinates)"
        }
        return "geo:\(coordinates)?q=\(coordinates)(\(encoded))"
    }

    /// Adds `https://` when no scheme was typed. `nil` if it can't be a link.
    static func link(_ input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        let hasScheme = trimmed.range(of: #"^[a-zA-Z][a-zA-Z0-9+.-]*:"#, options: .regularExpression) != nil
        guard let url = URL(string: hasScheme ? trimmed : "https://" + trimmed) else { return nil }
        if url.scheme == "http" || url.scheme == "https" {
            guard let host = url.host(), host.contains(".") || host == "localhost",
                  !host.hasPrefix("."), !host.hasSuffix(".") else { return nil }
        }
        return url
    }
}

private extension CharacterSet {
    /// Unreserved characters only (RFC 3986 §2.3).
    static let strictQueryValue = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
}
