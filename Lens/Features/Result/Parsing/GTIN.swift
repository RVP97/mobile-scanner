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
    static func region(for prefix: Int) -> String? {
        ranges.first { $0.range.contains(prefix) }?.name
    }

    private static let ranges: [(range: ClosedRange<Int>, name: String)] = [
        (0...19, "USA & Canada"), (30...39, "USA & Canada"), (60...139, "USA & Canada"),
        (200...299, "In-store code"), (300...379, "France"), (380...380, "Bulgaria"), (383...383, "Slovenia"),
        (385...385, "Croatia"), (387...387, "Bosnia and Herzegovina"), (389...389, "Montenegro"),
        (400...440, "Germany"), (450...459, "Japan"), (490...499, "Japan"), (460...469, "Russia"),
        (471...471, "Taiwan"), (474...474, "Estonia"), (475...475, "Latvia"), (477...477, "Lithuania"),
        (479...479, "Sri Lanka"), (480...480, "Philippines"), (482...482, "Ukraine"), (489...489, "Hong Kong"),
        (500...509, "United Kingdom"), (520...521, "Greece"), (528...528, "Lebanon"), (529...529, "Cyprus"),
        (535...535, "Malta"), (539...539, "Ireland"), (540...549, "Belgium & Luxembourg"),
        (560...560, "Portugal"), (569...569, "Iceland"), (570...579, "Denmark"), (590...590, "Poland"),
        (594...594, "Romania"), (599...599, "Hungary"), (600...601, "South Africa"), (611...611, "Morocco"),
        (616...616, "Kenya"), (622...622, "Egypt"), (628...628, "Saudi Arabia"), (629...629, "United Arab Emirates"),
        (640...649, "Finland"), (690...699, "China"), (700...709, "Norway"), (729...729, "Israel"),
        (730...739, "Sweden"), (740...740, "Guatemala"), (741...741, "El Salvador"), (742...742, "Honduras"),
        (743...743, "Nicaragua"), (744...744, "Costa Rica"), (745...745, "Panama"),
        (746...746, "Dominican Republic"), (750...750, "Mexico"), (754...755, "Canada"),
        (759...759, "Venezuela"), (760...769, "Switzerland"), (770...771, "Colombia"), (773...773, "Uruguay"),
        (775...775, "Peru"), (777...777, "Bolivia"), (778...779, "Argentina"), (780...780, "Chile"),
        (784...784, "Paraguay"), (786...786, "Ecuador"), (789...790, "Brazil"), (800...839, "Italy"),
        (840...849, "Spain"), (850...850, "Cuba"), (858...858, "Slovakia"), (859...859, "Czechia"),
        (860...860, "Serbia"), (868...869, "Türkiye"), (870...879, "Netherlands"), (880...880, "South Korea"),
        (885...885, "Thailand"), (888...888, "Singapore"), (890...890, "India"), (893...893, "Vietnam"),
        (899...899, "Indonesia"), (900...919, "Austria"), (930...939, "Australia"), (940...949, "New Zealand"),
        (955...955, "Malaysia"), (977...977, "Periodical (ISSN)"), (978...979, "Book (ISBN)"),
    ]
}
