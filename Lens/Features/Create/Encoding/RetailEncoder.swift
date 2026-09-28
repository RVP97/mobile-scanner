import Foundation

/// EAN-13, EAN-8, UPC-A and UPC-E (GS1 General Specifications §5.2).
nonisolated enum RetailEncoder {
    // Odd-parity ("L") left-hand patterns; "R" is its complement and "G" is "R" reversed.
    private static let lPatterns = [
        "0001101", "0011001", "0010011", "0111101", "0100011",
        "0110001", "0101111", "0111011", "0110111", "0001011",
    ]
    private static func pattern(_ digit: Int, _ set: Character) -> String {
        let l = lPatterns[digit]
        let r = String(l.map { $0 == "0" ? "1" : "0" })
        switch set {
        case "L": return l
        case "R": return r
        default: return String(r.reversed())
        }
    }

    /// EAN-13 left-half parity, selected by the leading digit.
    private static let ean13Parity = [
        "LLLLLL", "LLGLGG", "LLGGLG", "LLGGGL", "LGLLGG",
        "LGGLLG", "LGGGLL", "LGLGLG", "LGLGGL", "LGGLGL",
    ]
    /// UPC-E parity for number system 0, selected by the check digit ("G" = even). System 1 inverts it.
    private static let upcEParity = [
        "GGGLLL", "GGLGLL", "GGLLGL", "GGLLLG", "GLGGLL",
        "GLLGGL", "GLLLGG", "GLGLGL", "GLGLLG", "GLLGLG",
    ]

    // MARK: Check digits

    /// GS1 mod-10 check digit for a GTIN body (every digit except the check digit).
    static func checkDigit(for body: [Int]) -> Int {
        var sum = 0
        for (offset, digit) in body.reversed().enumerated() {
            sum += digit * (offset.isMultiple(of: 2) ? 3 : 1)
        }
        return (10 - sum % 10) % 10
    }

    static func checkDigit(for body: String) -> Int { checkDigit(for: digits(body)) }

    static func digits(_ text: String) -> [Int] { text.compactMap(\.wholeNumberValue) }

    // MARK: UPC-E ⇄ UPC-A

    /// Expands a 6-digit UPC-E body (without number system or check) to the 11-digit UPC-A body.
    static func expandUPCE(numberSystem: Int, _ x: [Int]) -> [Int] {
        precondition(x.count == 6)
        let tail: [Int]
        switch x[5] {
        case 0, 1, 2: tail = [x[0], x[1], x[5], 0, 0, 0, 0, x[2], x[3], x[4]]
        case 3: tail = [x[0], x[1], x[2], 0, 0, 0, 0, 0, x[3], x[4]]
        case 4: tail = [x[0], x[1], x[2], x[3], 0, 0, 0, 0, 0, x[4]]
        default: tail = [x[0], x[1], x[2], x[3], x[4], 0, 0, 0, 0, x[5]]
        }
        return [numberSystem] + tail
    }

    /// Zero-suppresses a 12-digit UPC-A into its 8-digit UPC-E form, if the number allows it.
    static func compressUPCA(_ upcA: String) -> String? {
        let d = digits(upcA)
        guard d.count == 12, d[0] == 0 || d[0] == 1 else { return nil }
        let m = Array(d[1...5]), p = Array(d[6...10])
        var body: [Int]?
        if m[2...4] == [0, 0, 0] || m[2...4] == [1, 0, 0] || m[2...4] == [2, 0, 0], p[0...1] == [0, 0] {
            body = [m[0], m[1], p[2], p[3], p[4], m[2]]
        } else if m[3...4] == [0, 0], p[0...2] == [0, 0, 0] {
            body = [m[0], m[1], m[2], p[3], p[4], 3]
        } else if m[4] == 0, p[0...3] == [0, 0, 0, 0] {
            body = [m[0], m[1], m[2], m[3], p[4], 4]
        } else if p[0...3] == [0, 0, 0, 0], p[4] >= 5 {
            body = m + [p[4]]
        }
        guard let body, expandUPCE(numberSystem: d[0], body) == Array(d[0...10]) else { return nil }
        return ([d[0]] + body + [d[11]]).map(String.init).joined()
    }

    // MARK: Symbols

    /// `digits` must be the full 13 digits including a correct check digit.
    static func ean13(_ digits: String) -> LinearBarcode {
        let d = self.digits(digits)
        var writer = ModuleWriter()
        var guards = IndexSet()
        func guardPattern(_ p: String) {
            guards.insert(integersIn: writer.modules.count..<(writer.modules.count + p.count))
            writer.append(pattern: p)
        }
        guardPattern("101")
        let parity = Array(ean13Parity[d[0]])
        for i in 1...6 { writer.append(pattern: pattern(d[i], parity[i - 1])) }
        guardPattern("01010")
        for i in 7...12 { writer.append(pattern: pattern(d[i], "R")) }
        guardPattern("101")

        var text = [LinearBarcode.TextRun(text: String(d[0]), start: -8, end: -1)]
        text += (1...6).map { run(d[$0], at: 3 + ($0 - 1) * 7) }
        text += (7...12).map { run(d[$0], at: 50 + ($0 - 7) * 7) }
        return LinearBarcode(modules: writer.modules, guardModules: guards, text: text, barHeight: 60, quietZone: 11)
    }

    static func ean8(_ digits: String) -> LinearBarcode {
        let d = self.digits(digits)
        var writer = ModuleWriter()
        var guards = IndexSet()
        func guardPattern(_ p: String) {
            guards.insert(integersIn: writer.modules.count..<(writer.modules.count + p.count))
            writer.append(pattern: p)
        }
        guardPattern("101")
        for i in 0...3 { writer.append(pattern: pattern(d[i], "L")) }
        guardPattern("01010")
        for i in 4...7 { writer.append(pattern: pattern(d[i], "R")) }
        guardPattern("101")
        let text = (0...3).map { run(d[$0], at: 3 + $0 * 7) } + (4...7).map { run(d[$0], at: 36 + ($0 - 4) * 7) }
        return LinearBarcode(modules: writer.modules, guardModules: guards, text: text, barHeight: 50, quietZone: 7)
    }

    /// UPC-A is EAN-13 with a leading zero, printed with the first and last digits outside the bars.
    static func upcA(_ digits: String) -> LinearBarcode {
        var symbol = ean13("0" + digits)
        let d = self.digits(digits)
        // The first and last digit's bars are drawn full height too.
        symbol.guardModules.insert(integersIn: 3..<10)
        symbol.guardModules.insert(integersIn: 85..<92)
        symbol.text = [LinearBarcode.TextRun(text: String(d[0]), start: -8, end: -1)]
            + (1...5).map { run(d[$0], at: 10 + ($0 - 1) * 7) }
            + (6...10).map { run(d[$0], at: 50 + ($0 - 6) * 7) }
            + [LinearBarcode.TextRun(text: String(d[11]), start: 96, end: 103)]
        return symbol
    }

    /// `digits`: 8 digits — number system, six data digits, check digit.
    static func upcE(_ digits: String) -> LinearBarcode {
        let d = self.digits(digits)
        let numberSystem = d[0], check = d[7]
        var parity = Array(upcEParity[check])
        if numberSystem == 1 { parity = parity.map { $0 == "G" ? "L" : "G" } }
        var writer = ModuleWriter()
        var guards = IndexSet(integersIn: 0..<3)
        writer.append(pattern: "101")
        for i in 0..<6 { writer.append(pattern: pattern(d[i + 1], parity[i])) }
        guards.insert(integersIn: writer.modules.count..<(writer.modules.count + 6))
        writer.append(pattern: "010101")
        let text = [LinearBarcode.TextRun(text: String(numberSystem), start: -8, end: -1)]
            + (0..<6).map { run(d[$0 + 1], at: 3 + $0 * 7) }
            + [LinearBarcode.TextRun(text: String(check), start: 52, end: 59)]
        return LinearBarcode(modules: writer.modules, guardModules: guards, text: text, barHeight: 50, quietZone: 9)
    }

    private static func run(_ digit: Int, at start: Int) -> LinearBarcode.TextRun {
        LinearBarcode.TextRun(text: String(digit), start: Double(start), end: Double(start + 7))
    }
}
