import Foundation

/// Industrial and logistics 1-D symbologies. Inputs are expected to be validated
/// (`SymbologyValidator`); invalid characters are skipped rather than trapping.
nonisolated enum LinearEncoders {
    /// Wide elements are three narrow modules: inside every spec's 2:1–3:1 range and the most robust.
    static let wide = 3

    // MARK: Code 39

    /// Nine elements per character (bar first); a set bit is a wide element.
    static let code39Table: [Character: UInt16] = [
        "0": 0x034, "1": 0x121, "2": 0x061, "3": 0x160, "4": 0x031, "5": 0x130, "6": 0x070, "7": 0x025,
        "8": 0x124, "9": 0x064, "A": 0x109, "B": 0x049, "C": 0x148, "D": 0x019, "E": 0x118, "F": 0x058,
        "G": 0x00D, "H": 0x10C, "I": 0x04C, "J": 0x01C, "K": 0x103, "L": 0x043, "M": 0x142, "N": 0x013,
        "O": 0x112, "P": 0x052, "Q": 0x007, "R": 0x106, "S": 0x046, "T": 0x016, "U": 0x181, "V": 0x0C1,
        "W": 0x1C0, "X": 0x091, "Y": 0x190, "Z": 0x0D0, "-": 0x085, ".": 0x184, " ": 0x0C4, "$": 0x0A8,
        "/": 0x0A2, "+": 0x08A, "%": 0x02A, "*": 0x094,
    ]

    static func code39(_ text: String) -> LinearBarcode {
        var writer = ModuleWriter()
        let characters = ["*"] + Array(text).filter { $0 != "*" && code39Table[$0] != nil } + ["*"]
        for (index, character) in characters.enumerated() {
            let bits = code39Table[character]!
            writer.append(elements: (0..<9).map { bits & (1 << (8 - $0)) != 0 }, wideWidth: wide)
            if index < characters.count - 1 { writer.append(space: 1) }
        }
        return LinearBarcode(modules: writer.modules, text: LinearBarcode.centeredText(text, over: writer.modules.count))
    }

    // MARK: Interleaved 2 of 5

    private static let itfTable = [
        "nnwwn", "wnnnw", "nwnnw", "wwnnn", "nnwnw", "wnwnn", "nwwnn", "nnnww", "wnnwn", "nwnwn",
    ].map { $0.map { $0 == "w" } }

    /// `digits` must have an even count.
    static func itf(_ digits: String) -> LinearBarcode {
        let d = RetailEncoder.digits(digits)
        var writer = ModuleWriter()
        writer.append(elements: [false, false, false, false])
        var index = 0
        while index + 1 < d.count {
            let bars = itfTable[d[index]], spaces = itfTable[d[index + 1]]
            var elements: [Bool] = []
            for i in 0..<5 { elements += [bars[i], spaces[i]] }
            writer.append(elements: elements, wideWidth: wide)
            index += 2
        }
        writer.append(elements: [true, false, false], wideWidth: wide)
        return LinearBarcode(modules: writer.modules, text: LinearBarcode.centeredText(digits, over: writer.modules.count))
    }

    // MARK: MSI (Modified Plessey)

    /// Luhn-style mod-10 check digit used by MSI.
    static func msiCheckDigit(_ digits: String) -> Int {
        var sum = 0
        for (offset, digit) in RetailEncoder.digits(digits).reversed().enumerated() {
            if offset.isMultiple(of: 2) {
                let doubled = digit * 2
                sum += doubled / 10 + doubled % 10
            } else {
                sum += digit
            }
        }
        return (10 - sum % 10) % 10
    }

    /// `digits` should already include its check digit.
    static func msi(_ digits: String) -> LinearBarcode {
        var writer = ModuleWriter()
        writer.append(pattern: "110")
        for digit in RetailEncoder.digits(digits) {
            for bit in (0..<4).reversed() {
                writer.append(pattern: digit & (1 << bit) != 0 ? "110" : "100")
            }
        }
        writer.append(pattern: "1001")
        return LinearBarcode(modules: writer.modules, text: LinearBarcode.centeredText(digits, over: writer.modules.count))
    }

    // MARK: Pharmacode (one-track)

    /// `value` must be within 3...131070.
    static func pharmacode(_ value: Int) -> LinearBarcode {
        var bars: [Bool] = []  // true = wide, most significant first
        var n = value
        while n > 0 {
            if n.isMultiple(of: 2) {
                bars.insert(true, at: 0)
                n = (n - 2) / 2
            } else {
                bars.insert(false, at: 0)
                n = (n - 1) / 2
            }
        }
        var writer = ModuleWriter()
        for (index, isWide) in bars.enumerated() {
            writer.append(bar: isWide ? wide : 1)
            if index < bars.count - 1 { writer.append(space: 2) }
        }
        return LinearBarcode(
            modules: writer.modules,
            text: LinearBarcode.centeredText(String(value), over: writer.modules.count),
            barHeight: 40,
            quietZone: 6
        )
    }

    // MARK: Codabar

    static let codabarAlphabet = Array("0123456789-$:/.+ABCD")
    private static let codabarTable: [UInt8] = [
        0x03, 0x06, 0x09, 0x60, 0x12, 0x42, 0x21, 0x24, 0x30, 0x48,
        0x0C, 0x18, 0x45, 0x51, 0x54, 0x15, 0x1A, 0x29, 0x0B, 0x0E,
    ]

    /// `text` must start and end with A–D.
    static func codabar(_ text: String) -> LinearBarcode {
        var writer = ModuleWriter()
        let characters = Array(text.uppercased())
        for (index, character) in characters.enumerated() {
            guard let position = codabarAlphabet.firstIndex(of: character) else { continue }
            let bits = codabarTable[position]
            writer.append(elements: (0..<7).map { bits & (1 << (6 - $0)) != 0 }, wideWidth: wide)
            if index < characters.count - 1 { writer.append(space: 1) }
        }
        let visible = characters.count > 2 ? String(characters.dropFirst().dropLast()) : text
        return LinearBarcode(modules: writer.modules, text: LinearBarcode.centeredText(visible, over: writer.modules.count))
    }
}
