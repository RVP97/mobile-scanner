import Foundation

/// One `NAME;PARAM=VALUE:value` line of a vCard or iCalendar object, after unfolding.
struct ContentLine {
    /// Uppercased property name without its group prefix ("TEL", "DTSTART").
    var name: String
    /// Uppercased parameter names. Bare 2.1-style params (`TEL;CELL:`) map to `TYPE`.
    var params: [String: String]
    /// The value exactly as written, escapes intact.
    var raw: String

    /// Value with text escapes (`\n` `\,` `\;` `\\`) resolved.
    var text: String { ContentLines.unescapeText(Substring(raw)) }

    /// Structured value (`N`, `ADR`, `ORG`) split on unescaped `;`, each component unescaped.
    var components: [String] {
        EscapedFields.split(Substring(raw), on: ";").map { ContentLines.unescapeText($0) }
    }
}

enum ContentLines {
    /// Unfolds (RFC 6350 §3.2 / RFC 5545 §3.1), joins quoted-printable soft breaks (vCard 2.1),
    /// and splits every line into name, params and value.
    static func parse(_ text: String) -> [ContentLine] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var logical: [String] = []
        for line in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            if let first = line.first, first == " " || first == "\t", !logical.isEmpty {
                logical[logical.count - 1] += line.dropFirst()
            } else if let last = logical.last, last.hasSuffix("="), last.uppercased().contains("QUOTED-PRINTABLE") {
                logical[logical.count - 1] = String(last.dropLast()) + line
            } else {
                logical.append(String(line))
            }
        }
        return logical.compactMap(contentLine)
    }

    private static func contentLine(_ line: String) -> ContentLine? {
        // The name/params part ends at the first colon outside a quoted param value.
        var inQuotes = false
        var colon: String.Index?
        for index in line.indices {
            let character = line[index]
            if character == "\"" { inQuotes.toggle() }
            if character == ":", !inQuotes {
                colon = index
                break
            }
        }
        guard let colon else { return nil }

        let head = line[..<colon].split(separator: ";", omittingEmptySubsequences: false)
        guard var name = head.first.map(String.init)?.trimmed.uppercased(), !name.isEmpty else { return nil }
        if let dot = name.lastIndex(of: ".") { name = String(name[name.index(after: dot)...]) }

        var params: [String: String] = [:]
        for param in head.dropFirst() {
            let pieces = param.split(separator: "=", maxSplits: 1)
            if pieces.count == 2 {
                let key = pieces[0].uppercased()
                let value = pieces[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                params[key] = params[key].map { "\($0),\(value)" } ?? value
            } else if let bare = pieces.first {
                params["TYPE"] = params["TYPE"].map { "\($0),\(bare)" } ?? String(bare)
            }
        }

        var raw = String(line[line.index(after: colon)...])
        if params["ENCODING"]?.uppercased() == "QUOTED-PRINTABLE" {
            raw = decodeQuotedPrintable(raw)
        }
        return ContentLine(name: name, params: params, raw: raw)
    }

    static func unescapeText(_ text: Substring) -> String {
        var output = ""
        var escaping = false
        for character in text {
            if escaping {
                output.append(character == "n" || character == "N" ? "\n" : character)
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                output.append(character)
            }
        }
        return output
    }

    static func decodeQuotedPrintable(_ text: String) -> String {
        var bytes: [UInt8] = []
        let utf8 = Array(text.utf8)
        var index = 0
        while index < utf8.count {
            if utf8[index] == UInt8(ascii: "="), index + 2 < utf8.count,
               let byte = UInt8(String(decoding: utf8[(index + 1)...(index + 2)], as: UTF8.self), radix: 16) {
                bytes.append(byte)
                index += 3
            } else {
                bytes.append(utf8[index])
                index += 1
            }
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
