import Foundation

/// Retail item numbers: EAN-8, UPC-A (12), EAN-13 and GTIN-14, plus UPC-E expansion.
enum GTIN {
    static let lengths: Set<Int> = [8, 12, 13, 14]

    /// Mod-10 check with alternating 3/1 weights from the right.
    static func hasValidCheckDigit(_ digits: String) -> Bool {
        guard digits.isAllDigits, lengths.contains(digits.count) else { return false }
        let values = digits.compactMap(\.wholeNumberValue)
        return checkDigit(for: values.dropLast()) == values.last
    }

    static func checkDigit<C: Collection>(for body: C) -> Int where C.Element == Int {
        let sum = body.reversed().enumerated().reduce(0) { total, item in
            total + item.element * (item.offset.isMultiple(of: 2) ? 3 : 1)
        }
        return (10 - sum % 10) % 10
    }

    /// Expands a 6-, 7- or 8-digit UPC-E to its 12-digit UPC-A. Returns nil for malformed input.
    static func expandUPCE(_ code: String) -> String? {
        guard code.isAllDigits else { return nil }
        let digits: [Int]
        switch code.count {
        case 6: digits = [0] + code.compactMap(\.wholeNumberValue)
        case 7, 8: digits = code.prefix(7).compactMap(\.wholeNumberValue)
        default: return nil
        }
        let system = digits[0]
        guard system == 0 || system == 1 else { return nil }
        let d = Array(digits[1...6])
        let body: [Int] = switch d[5] {
        case 0, 1, 2: [system, d[0], d[1], d[5], 0, 0, 0, 0, d[2], d[3], d[4]]
        case 3: [system, d[0], d[1], d[2], 0, 0, 0, 0, 0, d[3], d[4]]
        case 4: [system, d[0], d[1], d[2], d[3], 0, 0, 0, 0, 0, d[4]]
        default: [system, d[0], d[1], d[2], d[3], d[4], 0, 0, 0, 0, d[5]]
        }
        let check = checkDigit(for: body)
        if code.count == 8, code.last?.wholeNumberValue != check { return nil }
        return (body + [check]).map(String.init).joined()
    }

    /// The canonical number for a scanned retail code: UPC-E expanded, AVFoundation's
    /// zero-padded UPC-A trimmed back to 12 digits, GTIN-14 with a leading zero reduced to 13.
    static func normalize(_ digits: String, symbology: Symbology) -> String {
        switch symbology {
        case .upcE: return expandUPCE(digits) ?? digits
        case .upcA where digits.count == 13 && digits.hasPrefix("0"): return String(digits.dropFirst())
        default: break
        }
        if digits.count == 14, digits.hasPrefix("0"), hasValidCheckDigit(digits) { return String(digits.dropFirst()) }
        return digits
    }

    /// Code to send to product databases (they index UPC-A as a zero-padded EAN-13).
    static func lookupCode(_ gtin: String) -> String {
        gtin.count == 12 ? "0" + gtin : gtin
    }

    /// "EAN-13", "UPC-A"…
    static func formatName(_ gtin: String) -> String {
        switch gtin.count {
        case 8: "EAN-8"
        case 12: "UPC-A"
        case 13: gtin.hasPrefix("978") || gtin.hasPrefix("979") ? "ISBN" : "EAN-13"
        case 14: "GTIN-14"
        default: "GTIN"
        }
    }

    /// Groups digits the way they're printed under the bars: "4 006381 333931", "0 36000 29145 2".
    static func grouped(_ gtin: String) -> String {
        let characters = Array(gtin)
        let groups: [Int] = switch gtin.count {
        case 13: [1, 6, 6]
        case 12: [1, 5, 5, 1]
        case 8: [4, 4]
        case 14: [1, 2, 5, 5, 1]
        default: [gtin.count]
        }
        var output: [String] = []
        var index = 0
        for size in groups where index + size <= characters.count {
            output.append(String(characters[index..<(index + size)]))
            index += size
        }
        return output.joined(separator: " ")
    }

    /// GS1 member organisation that issued the company prefix (not where it was made).
    static func prefixRegion(_ gtin: String) -> String? {
        let full = gtin.count == 12 ? "0" + gtin : gtin
        guard full.count == 13, let prefix = Int(full.prefix(3)) else { return nil }
        return GS1Prefixes.region(for: prefix)
    }
}

enum GS1Prefixes {
    static func region(for prefix: Int, locale: Locale = .current) -> String? {
        switch ranges.first(where: { $0.range.contains(prefix) })?.name {
        case .country(let code): locale.localizedString(forRegionCode: code) ?? code
        case .label(let label): String(localized: label)
        case nil: nil
        }
    }

    /// A single country (named by the system, in the reader's language) or a label of our own.
    private enum Name {
        case country(String)
        case label(LocalizedStringResource)
    }

    private static let ranges: [(range: ClosedRange<Int>, name: Name)] = [
        (0...19, .label("USA & Canada")), (30...39, .label("USA & Canada")), (60...139, .label("USA & Canada")),
        (200...299, .label("In-store code")), (300...379, .country("FR")), (380...380, .country("BG")), (383...383, .country("SI")),
        (385...385, .country("HR")), (387...387, .country("BA")), (389...389, .country("ME")),
        (400...440, .country("DE")), (450...459, .country("JP")), (490...499, .country("JP")), (460...469, .country("RU")),
        (471...471, .country("TW")), (474...474, .country("EE")), (475...475, .country("LV")), (477...477, .country("LT")),
        (479...479, .country("LK")), (480...480, .country("PH")), (482...482, .country("UA")), (489...489, .label("Hong Kong")),
        (500...509, .country("GB")), (520...521, .country("GR")), (528...528, .country("LB")), (529...529, .country("CY")),
        (535...535, .country("MT")), (539...539, .country("IE")), (540...549, .label("Belgium & Luxembourg")),
        (560...560, .country("PT")), (569...569, .country("IS")), (570...579, .country("DK")), (590...590, .country("PL")),
        (594...594, .country("RO")), (599...599, .country("HU")), (600...601, .country("ZA")), (611...611, .country("MA")),
        (616...616, .country("KE")), (622...622, .country("EG")), (628...628, .country("SA")), (629...629, .country("AE")),
        (640...649, .country("FI")), (690...699, .country("CN")), (700...709, .country("NO")), (729...729, .country("IL")),
        (730...739, .country("SE")), (740...740, .country("GT")), (741...741, .country("SV")), (742...742, .country("HN")),
        (743...743, .country("NI")), (744...744, .country("CR")), (745...745, .country("PA")),
        (746...746, .country("DO")), (750...750, .country("MX")), (754...755, .country("CA")),
        (759...759, .country("VE")), (760...769, .country("CH")), (770...771, .country("CO")), (773...773, .country("UY")),
        (775...775, .country("PE")), (777...777, .country("BO")), (778...779, .country("AR")), (780...780, .country("CL")),
        (784...784, .country("PY")), (786...786, .country("EC")), (789...790, .country("BR")), (800...839, .country("IT")),
        (840...849, .country("ES")), (850...850, .country("CU")), (858...858, .country("SK")), (859...859, .country("CZ")),
        (860...860, .country("RS")), (868...869, .country("TR")), (870...879, .country("NL")), (880...880, .country("KR")),
        (885...885, .country("TH")), (888...888, .country("SG")), (890...890, .country("IN")), (893...893, .country("VN")),
        (899...899, .country("ID")), (900...919, .country("AT")), (930...939, .country("AU")), (940...949, .country("NZ")),
        (955...955, .country("MY")), (977...977, .label("Periodical (ISSN)")), (978...979, .label("Book (ISBN)")),
    ]
}
