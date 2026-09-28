import Foundation

/// Reads the `KEY:value;KEY:value;;` payloads used by `WIFI:`, `MECARD:` and `MATMSG:`,
/// where `\` escapes the reserved characters `;` `,` `:` and `\`.
enum EscapedFields {
    struct Field {
        /// Uppercased key ("S", "TEL").
        var key: String
        /// The value exactly as printed, escapes intact, so it can be split again.
        var raw: Substring
        var value: String { EscapedFields.unescape(raw) }
    }

    static func fields(_ body: Substring) -> [Field] {
        split(body, on: ";").compactMap { part in
            guard let colon = part.firstIndex(of: ":") else { return nil }
            let key = part[..<colon].trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !key.isEmpty else { return nil }
            return Field(key: key, raw: part[part.index(after: colon)...])
        }
    }

    /// Splits on `separator` wherever it isn't escaped. Escapes are preserved.
    static func split(_ text: Substring, on separator: Character) -> [Substring] {
        var parts: [Substring] = []
        var start = text.startIndex
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == "\\" {
                index = text.index(after: index)
                if index < text.endIndex { index = text.index(after: index) }
                continue
            }
            if character == separator {
                parts.append(text[start..<index])
                start = text.index(after: index)
            }
            index = text.index(after: index)
        }
        parts.append(text[start..<text.endIndex])
        return parts
    }

    static func unescape(_ text: Substring) -> String {
        var output = ""
        var escaping = false
        for character in text {
            if escaping {
                output.append(character)
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                output.append(character)
            }
        }
        return output
    }
}

extension String {
    /// Case-insensitive prefix test for URI schemes and headers.
    func hasPrefixIgnoringCase(_ prefix: String) -> Bool {
        guard count >= prefix.count else { return false }
        return self.prefix(prefix.count).lowercased() == prefix.lowercased()
    }

    var isAllDigits: Bool { !isEmpty && allSatisfy(\.isASCIIDigit) }

    /// Percent-decoded, falling back to the original text when it isn't valid encoding.
    var percentDecoded: String { removingPercentEncoding ?? self }

    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}

/// Minimal `a=1&b=2` reader for URI query strings that URLComponents rejects (spaces, raw unicode).
enum QueryString {
    static func parameters(_ query: Substring) -> [String: String] {
        var result: [String: String] = [:]
        for pair in query.split(separator: "&") {
            let pieces = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let key = String(pieces[0]).percentDecoded.lowercased()
            let value = pieces.count > 1 ? String(pieces[1]).percentDecoded : ""
            if result[key] == nil { result[key] = value }
        }
        return result
    }
}
