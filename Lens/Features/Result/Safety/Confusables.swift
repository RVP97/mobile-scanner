import Foundation

/// Reduces a domain label to the letters it *looks like*, so `n0rthbank`, `rnicrosoft`
/// and Cyrillic `аpple` compare equal to the names they imitate.
enum Confusables {
    /// Single characters that pass for a Latin letter.
    static let lookalikes: [Character: Character] = [
        // Digits
        "0": "o", "1": "l", "3": "e", "5": "s",
        // Cyrillic
        "а": "a", "в": "b", "е": "e", "ё": "e", "о": "o", "р": "p", "с": "c", "у": "y", "х": "x",
        "к": "k", "м": "m", "н": "h", "т": "t", "і": "i", "ї": "i", "ј": "j", "ӏ": "l", "ԁ": "d",
        "ԛ": "q", "ԝ": "w", "ѕ": "s", "һ": "h", "ү": "y", "ɡ": "g", "ո": "n", "ս": "u",
        // Greek
        "α": "a", "ο": "o", "ρ": "p", "ν": "v", "ι": "i", "κ": "k", "τ": "t", "υ": "u", "χ": "x",
        "ε": "e", "γ": "y", "η": "n", "ω": "w",
        // Latin extensions
        "ı": "i", "ɩ": "l", "ǀ": "l", "ℓ": "l", "ł": "l", "ø": "o", "đ": "d", "ħ": "h",
    ]

    /// Letter pairs that read as one letter at a glance.
    static let digraphs: [(String, String)] = [("rn", "m"), ("vv", "w"), ("cl", "d")]

    static func skeleton(_ label: String) -> String {
        let folded = label
            .precomposedStringWithCompatibilityMapping
            .lowercased()
        var mapped = ""
        for character in folded {
            if let latin = lookalikes[character] {
                mapped.append(latin)
            } else {
                mapped.append(contentsOf: String(character).folding(options: .diacriticInsensitive, locale: nil))
            }
        }
        for (pair, letter) in digraphs {
            mapped = mapped.replacingOccurrences(of: pair, with: letter)
        }
        return mapped
    }

    enum Script: Hashable { case latin, greek, cyrillic, other }

    static func scripts(in label: String) -> Set<Script> {
        var result: Set<Script> = []
        for scalar in label.unicodeScalars where scalar.properties.isAlphabetic {
            switch scalar.value {
            case 0x41...0x5A, 0x61...0x7A, 0xC0...0x24F, 0x1E00...0x1EFF: result.insert(.latin)
            case 0x370...0x3FF, 0x1F00...0x1FFF: result.insert(.greek)
            case 0x400...0x52F: result.insert(.cyrillic)
            default: result.insert(.other)
            }
        }
        return result
    }

    /// Latin mixed with Greek or Cyrillic inside one label: the classic homograph.
    static func mixesScripts(_ label: String) -> Bool {
        scripts(in: label).intersection([.latin, .greek, .cyrillic]).count > 1
    }

    /// Levenshtein distance, bailing out early once it exceeds `limit`.
    static func distance(_ a: String, _ b: String, limit: Int = .max) -> Int {
        let a = Array(a), b = Array(b)
        if abs(a.count - b.count) > limit { return limit + 1 }
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        var current = Array(repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            var rowMinimum = current[0]
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                rowMinimum = min(rowMinimum, current[j])
            }
            if rowMinimum > limit { return limit + 1 }
            swap(&previous, &current)
        }
        return previous[b.count]
    }
}
