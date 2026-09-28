import Foundation

/// `mailto:`, `MATMSG:`, `sms:`/`smsto:`, `tel:` and `geo:`.
enum MessageParsers {
    // MARK: Email

    static func mailto(_ raw: String) -> EmailMessage? {
        guard raw.hasPrefixIgnoringCase("mailto:") else { return nil }
        let rest = raw.dropFirst(7)
        let question = rest.firstIndex(of: "?")
        var to = String(rest[..<(question ?? rest.endIndex)]).percentDecoded.trimmed
        var message = EmailMessage(to: "")
        if let question {
            let query = QueryString.parameters(rest[rest.index(after: question)...])
            if to.isEmpty { to = query["to"] ?? "" }
            message.subject = query["subject"] ?? ""
            message.body = query["body"] ?? ""
        }
        message.to = to
        return message
    }

    static func matmsg(_ raw: String) -> EmailMessage? {
        guard raw.hasPrefixIgnoringCase("MATMSG:") else { return nil }
        var message = EmailMessage(to: "")
        for field in EscapedFields.fields(raw.dropFirst(7)) {
            switch field.key {
            case "TO": message.to = field.value.trimmed
            case "SUB": message.subject = field.value
            case "BODY": message.body = field.value
            default: break
            }
        }
        return message
    }

    /// A bare `name@domain.tld`.
    static func bareEmail(_ raw: String) -> EmailMessage? {
        let pattern = /^[A-Za-z0-9._%+\-]+@[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?)*\.[A-Za-z]{2,}$/
        guard raw.wholeMatch(of: pattern) != nil else { return nil }
        return EmailMessage(to: raw)
    }

    // MARK: SMS

    /// `sms:+15551234567?body=Hi`, `sms:+1555&body=Hi` (iOS), `SMSTO:+1555:Hi`, `mmsto:`.
    static func sms(_ raw: String) -> SMSMessage? {
        let schemes = ["smsto:", "mmsto:", "sms:", "mms:"]
        guard let scheme = schemes.first(where: raw.hasPrefixIgnoringCase) else { return nil }
        let rest = raw.dropFirst(scheme.count)
        let separators: Set<Character> = ["?", "&", ";", ":"]
        let end = rest.firstIndex(where: separators.contains) ?? rest.endIndex
        let number = String(rest[..<end]).percentDecoded.trimmed
        var body = ""
        if end < rest.endIndex {
            let tail = rest[rest.index(after: end)...]
            if rest[end] == ":", !tail.lowercased().hasPrefix("body=") {
                body = String(tail)
            } else if let range = tail.range(of: "body=", options: .caseInsensitive) {
                body = QueryString.parameters(tail[range.lowerBound...])["body"] ?? ""
            }
        }
        guard !number.isEmpty || !body.isEmpty else { return nil }
        return SMSMessage(number: number, body: body)
    }

    // MARK: Phone

    static func tel(_ raw: String) -> String? {
        guard raw.hasPrefixIgnoringCase("tel:") else { return nil }
        let number = String(raw.dropFirst(4)).percentDecoded.trimmed
        guard number.contains(where: \.isASCIIDigit) else { return nil }
        return number
    }

    // MARK: Location

    /// `geo:19.4326,-99.1332`, `geo:19.43,-99.13,2240?q=Atlas`, Android `geo:0,0?q=19.43,-99.13(Atlas)`
    /// or `geo:0,0?q=Some+address` (coordinates 0,0 with a label means "search for the label").
    static func geo(_ raw: String) -> GeoPoint? {
        guard raw.hasPrefixIgnoringCase("geo:") else { return nil }
        let rest = raw.dropFirst(4)
        let question = rest.firstIndex(of: "?")
        let path = rest[..<(question ?? rest.endIndex)].split(separator: ";").first ?? ""
        let numbers = path.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard numbers.count >= 2 else { return nil }
        var point = GeoPoint(latitude: numbers[0], longitude: numbers[1])

        if let question {
            let rawQuery = rest[rest.index(after: question)...].replacingOccurrences(of: "+", with: " ")
            let query = QueryString.parameters(Substring(rawQuery))["q"] ?? ""
            if let embedded = coordinatesWithLabel(query), point.latitude == 0, point.longitude == 0 {
                point = embedded
            } else {
                point.label = query.trimmed
            }
        }
        guard (-90...90).contains(point.latitude), (-180...180).contains(point.longitude) else { return nil }
        return point
    }

    /// `19.43,-99.13(Atlas Coffee)` inside a `q=` parameter.
    private static func coordinatesWithLabel(_ query: String) -> GeoPoint? {
        let pattern = /^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*(?:\((.*)\))?\s*$/
        guard let match = query.wholeMatch(of: pattern),
              let latitude = Double(match.1), let longitude = Double(match.2)
        else { return nil }
        return GeoPoint(latitude: latitude, longitude: longitude, label: match.3.map(String.init) ?? "")
    }
}
