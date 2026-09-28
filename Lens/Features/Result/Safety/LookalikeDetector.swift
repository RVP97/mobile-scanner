import Foundation

/// A host that imitates a known brand, with the characters that give it away.
struct LookalikeMatch: Hashable {
    enum Kind: Hashable {
        /// Same name, other letters that look identical (`n0rthbank`, Cyrillic `аpple`).
        case homograph
        /// A typo away from the brand (`paypall`, `amazom`).
        case typo
        /// The brand's exact name on another TLD (`chase.co`).
        case otherTLD
        /// The brand's domain placed in front of someone else's (`paypal.com.secure-login.io`).
        case brandAsSubdomain
        /// The brand's name as one word of a longer domain (`paypal-secure.io`).
        case brandInName
    }

    var brand: Brand
    var kind: Kind
    /// Offsets (in `Character`s) of the suspicious letters within the host.
    var flaggedOffsets: [Int] = []
    /// Plain-language note about the first flagged letter ("That's a zero, not the letter “o”.").
    var note: String?
}

enum LookalikeDetector {
    /// `host` is lowercase and already punycode-decoded.
    static func match(host: String) -> LookalikeMatch? {
        let registrable = DomainRules.registrableDomain(host)
        if BrandDomains.owner(ofRegistrable: registrable) != nil { return nil }
        let label = DomainRules.label(ofRegistrable: registrable)
        let skeleton = Confusables.skeleton(label)
        let tokens = label.split(separator: "-").map(String.init)

        // Common words and short names only count when foreign letters are involved ("a11y" isn't Ally Bank).
        let hasForeignLetters = !label.allSatisfy(\.isASCII)
        for brand in BrandDomains.all where brand.label.count >= 3 && (!brand.isCommonWord || hasForeignLetters) {
            let brandSkeleton = Confusables.skeleton(brand.label)
            if skeleton == brandSkeleton, label != brand.label {
                return annotated(LookalikeMatch(brand: brand, kind: .homograph), host: host, label: label, brandLabel: brand.label)
            }
            if tokens.count > 1, let token = tokens.first(where: { Confusables.skeleton($0) == brandSkeleton && $0 != brand.label }),
               token.count >= 3 {
                return annotated(LookalikeMatch(brand: brand, kind: .homograph), host: host, label: token, brandLabel: brand.label)
            }
        }

        for brand in BrandDomains.all where !brand.isCommonWord {
            if label == brand.label {
                return LookalikeMatch(brand: brand, kind: .otherTLD)
            }
            let subdomainWords = DomainRules.subdomainLabels(host).flatMap { $0.split(separator: "-").map(String.init) }
            if subdomainWords.contains(brand.label) {
                return LookalikeMatch(brand: brand, kind: .brandAsSubdomain)
            }
            if tokens.count > 1, tokens.contains(brand.label) {
                return LookalikeMatch(brand: brand, kind: .brandInName)
            }
        }

        for brand in BrandDomains.all where !brand.isCommonWord {
            let limit = brand.label.count >= 9 ? 2 : (brand.label.count >= 5 ? 1 : 0)
            guard limit > 0 else { continue }
            let candidates = [skeleton] + tokens.map(Confusables.skeleton)
            if candidates.contains(where: { Confusables.distance($0, brand.label, limit: limit) <= limit && $0.count >= 4 }) {
                return LookalikeMatch(brand: brand, kind: .typo)
            }
        }
        return nil
    }

    /// Marks lookalike characters of `label` (wherever it sits in `host`) and explains the first one.
    private static func annotated(_ match: LookalikeMatch, host: String, label: String, brandLabel: String) -> LookalikeMatch {
        var match = match
        let hostCharacters = Array(host)
        let labelCharacters = Array(label)
        guard let start = firstOffset(of: labelCharacters, in: hostCharacters) else { return match }

        var index = 0
        while index < labelCharacters.count {
            let character = labelCharacters[index]
            let pair = index + 1 < labelCharacters.count ? String(labelCharacters[index...index + 1]) : ""
            if let digraph = Confusables.digraphs.first(where: { $0.0 == pair }), !brandLabel.contains(pair),
               brandLabel.contains(digraph.1) {
                match.flaggedOffsets += [start + index, start + index + 1]
                match.note = match.note ?? String(localized: "That's “\(pair)”, not the letter “\(digraph.1)”.")
                index += 2
                continue
            }
            if let latin = Confusables.lookalikes[character], !brandLabel.contains(character) {
                match.flaggedOffsets.append(start + index)
                match.note = match.note ?? note(for: character, imitating: latin)
            } else if !character.isASCII,
                      let latin = String(character).folding(options: .diacriticInsensitive, locale: nil).first {
                match.flaggedOffsets.append(start + index)
                match.note = match.note ?? note(for: character, imitating: latin)
            }
            index += 1
        }
        return match
    }

    private static func note(for character: Character, imitating latin: Character) -> String {
        switch character {
        case "0": return String(localized: "That's a zero, not the letter “o”.")
        case "1": return String(localized: "That's the number one, not the letter “l”.")
        case "3", "5": return String(localized: "That's the number \(String(character)), not the letter “\(String(latin))”.")
        default:
            let script = Confusables.scripts(in: String(character))
            if script.contains(.cyrillic) {
                return String(localized: "That “\(String(character))” is a Cyrillic letter, not a Latin “\(String(latin))”.")
            }
            if script.contains(.greek) {
                return String(localized: "That “\(String(character))” is a Greek letter, not a Latin “\(String(latin))”.")
            }
            return String(localized: "That “\(String(character))” only looks like “\(String(latin))”.")
        }
    }

    private static func firstOffset(of needle: [Character], in haystack: [Character]) -> Int? {
        guard !needle.isEmpty, needle.count <= haystack.count else { return nil }
        return (0...(haystack.count - needle.count)).first { Array(haystack[$0..<($0 + needle.count)]) == needle }
    }
}
