import Foundation

/// vCard 2.1 / 3.0 / 4.0 and DoCoMo `MECARD:`.
enum ContactParser {
    static func parseVCard(_ raw: String) -> ContactCard? {
        guard raw.trimmed.hasPrefixIgnoringCase("BEGIN:VCARD") else { return nil }
        var card = ContactCard()
        var formattedName = ""

        for line in ContentLines.parse(raw) {
            switch line.name {
            case "N":
                let parts = line.components
                card.familyName = parts.first?.trimmed ?? ""
                card.givenName = parts.count > 1 ? parts[1].trimmed : ""
            case "FN":
                formattedName = line.text.trimmed
            case "ORG":
                card.organization = line.components.first?.trimmed ?? ""
            case "TITLE":
                card.jobTitle = line.text.trimmed
            case "TEL":
                appendUnique(stripScheme(line.text, "tel:"), to: &card.phones)
            case "EMAIL":
                appendUnique(stripScheme(line.text, "mailto:"), to: &card.emails)
            case "URL":
                appendUnique(line.text.trimmed, to: &card.urls)
            case "ADR":
                card.address = formatAddress(line.components)
            case "NOTE":
                card.note = line.text.trimmed
            default:
                break
            }
        }
        if card.fullName.isEmpty { splitFullName(formattedName, into: &card) }
        return card
    }

    static func parseMeCard(_ raw: String) -> ContactCard? {
        guard raw.hasPrefixIgnoringCase("MECARD:") else { return nil }
        var card = ContactCard()
        for field in EscapedFields.fields(raw.dropFirst(7)) {
            switch field.key {
            case "N":
                let parts = EscapedFields.split(field.raw, on: ",").map { EscapedFields.unescape($0).trimmed }
                if parts.count > 1 {
                    card.familyName = parts[0]
                    card.givenName = parts[1]
                } else {
                    splitFullName(parts.first ?? "", into: &card)
                }
            case "ORG": card.organization = field.value.trimmed
            case "TITLE": card.jobTitle = field.value.trimmed
            case "TEL", "TEL-AV": appendUnique(field.value, to: &card.phones)
            case "EMAIL": appendUnique(field.value, to: &card.emails)
            case "URL": appendUnique(field.value, to: &card.urls)
            case "ADR": card.address = field.value.trimmed
            case "NOTE": card.note = field.value.trimmed
            default: break
            }
        }
        return card
    }

    // MARK: Helpers

    /// Post office box, extended, street, locality, region, postal code, country.
    private static func formatAddress(_ parts: [String]) -> String {
        parts.map(\.trimmed).filter { !$0.isEmpty }.joined(separator: ", ")
    }

    private static func splitFullName(_ name: String, into card: inout ContactCard) {
        let name = name.trimmed
        guard !name.isEmpty else { return }
        if let space = name.lastIndex(of: " ") {
            card.givenName = String(name[..<space]).trimmed
            card.familyName = String(name[name.index(after: space)...])
        } else {
            card.givenName = name
        }
    }

    private static func stripScheme(_ value: String, _ scheme: String) -> String {
        let value = value.trimmed
        return value.hasPrefixIgnoringCase(scheme) ? String(value.dropFirst(scheme.count)) : value
    }

    private static func appendUnique(_ value: String, to list: inout [String]) {
        let value = value.trimmed
        if !value.isEmpty, !list.contains(value) { list.append(value) }
    }
}
