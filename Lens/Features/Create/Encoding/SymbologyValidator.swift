import Foundation

/// A one-tap correction offered next to a validation message.
nonisolated struct InputFix: Sendable {
    var title: LocalizedStringResource
    var replacement: String
}

/// Live verdict on what the person typed for a given format.
nonisolated enum InputCheck: Sendable {
    case empty
    /// `value` is what gets encoded; `note` explains anything Lens added (a check digit, start/stop).
    case valid(String, note: LocalizedStringResource? = nil)
    case invalid(LocalizedStringResource, fix: InputFix? = nil)

    var value: String? {
        if case .valid(let value, _) = self { value } else { nil }
    }
}

/// Format rules, written the way a person would explain them.
enum SymbologyValidator {
    static let code39Characters = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. $/+%")
    static let codabarData = Set("0123456789-$:/.+")
    static let codabarGuards = Set("ABCD")

    static func check(_ input: String, for symbology: Symbology) -> InputCheck {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        switch symbology {
        case .qr: return capacity(trimmed, maxBytes: 2_900, symbology)
        case .aztec: return capacity(trimmed, maxBytes: 3_000, symbology)
        case .pdf417: return capacity(trimmed, maxBytes: 1_800, symbology)
        case .dataMatrix:
            return DataMatrixEncoder.dataCodewords(for: trimmed).count <= DataMatrixEncoder.maximumDataCodewords
                ? .valid(trimmed) : .invalid("That's too long for a Data Matrix code. Try a QR code instead.")
        case .code128: return code128(trimmed)
        case .ean13: return gtin(trimmed, length: 13, name: "EAN-13")
        case .ean8: return gtin(trimmed, length: 8, name: "EAN-8")
        case .upcA: return gtin(trimmed, length: 12, name: "UPC-A")
        case .itf14: return gtin(trimmed, length: 14, name: "ITF-14")
        case .upcE: return upcE(trimmed)
        case .code39: return code39(trimmed)
        case .itf: return itf(trimmed)
        case .msi: return msi(trimmed)
        case .pharmacode: return pharmacode(trimmed)
        case .codabar: return codabar(trimmed)
        case .microQR, .microPDF417, .code93, .gs1DataBar:
            return .invalid("Lens can read \(symbology.displayName) but can't make it yet.")
        }
    }

    // MARK: 2-D and Code 128

    private static func capacity(_ text: String, maxBytes: Int, _ symbology: Symbology) -> InputCheck {
        text.utf8.count <= maxBytes
            ? .valid(text)
            : .invalid("That's too long for \(symbology.displayName). Keep it under \(maxBytes) characters.")
    }

    private static func code128(_ text: String) -> InputCheck {
        if let bad = text.first(where: { !$0.isASCII || ($0.asciiValue ?? 0) < 32 }) {
            return .invalid("Code 128 can't hold “\(String(bad))”. Use letters, digits and standard symbols.")
        }
        return text.count <= 80 ? .valid(text) : .invalid("Keep Code 128 under 80 characters so it fits on a label.")
    }

    // MARK: Retail and logistics numbers

    /// Digits with spaces and dashes removed, or `nil` if anything else is in there.
    static func digitsOnly(_ text: String) -> String? {
        let cleaned = text.filter { $0 != " " && $0 != "-" }
        return cleaned.allSatisfy(\.isASCIIDigit) ? cleaned : nil
    }

    private static func gtin(_ text: String, length: Int, name: String) -> InputCheck {
        guard let digits = digitsOnly(text) else { return .invalid("\(name) uses digits only.") }
        if digits.count == length - 1 {
            let check = RetailEncoder.checkDigit(for: digits)
            return .valid(digits + String(check), note: "Check digit \(check) added.")
        }
        guard digits.count == length else {
            return .invalid("\(name) needs \(length - 1) or \(length) digits. This has \(digits.count).")
        }
        let body = String(digits.dropLast())
        let expected = RetailEncoder.checkDigit(for: body)
        guard digits.last?.wholeNumberValue == expected else {
            return .invalid(
                "The last digit should be \(expected) — it's the check digit.",
                fix: InputFix(title: "Use \(expected)", replacement: body + String(expected))
            )
        }
        return .valid(digits)
    }

    private static func upcE(_ text: String) -> InputCheck {
        guard let digits = digitsOnly(text) else { return .invalid("UPC-E uses digits only.") }
        switch digits.count {
        case 12:
            let upcA = gtin(digits, length: 12, name: "UPC-A")
            guard let full = upcA.value else { return upcA }
            guard let compressed = RetailEncoder.compressUPCA(full) else {
                return .invalid("This UPC-A number has too few zeros to shorten into UPC-E. Use UPC-A instead.")
            }
            return .valid(compressed, note: "Shortened from UPC-A \(full).")
        case 6, 7, 8:
            let d = RetailEncoder.digits(digits)
            let hasSystem = digits.count >= 7
            let system = hasSystem ? d[0] : 0
            guard system <= 1 else { return .invalid("UPC-E numbers start with 0 or 1.") }
            let body = Array(d[(hasSystem ? 1 : 0)..<(hasSystem ? 7 : 6)])
            let check = RetailEncoder.checkDigit(for: RetailEncoder.expandUPCE(numberSystem: system, body))
            let value = ([system] + body + [check]).map(String.init).joined()
            if digits.count == 8, d[7] != check {
                return .invalid(
                    "The last digit should be \(check) — it's the check digit.",
                    fix: InputFix(title: "Use \(check)", replacement: value)
                )
            }
            return .valid(value, note: digits.count == 8 ? nil : "Check digit \(check) added.")
        default:
            return .invalid("UPC-E needs 6 to 8 digits, or a 12-digit UPC-A to shorten. This has \(digits.count).")
        }
    }

    private static func itf(_ text: String) -> InputCheck {
        guard let digits = digitsOnly(text) else { return .invalid("ITF uses digits only.") }
        guard digits.count.isMultiple(of: 2) else {
            return .invalid("ITF encodes digits in pairs, so it needs an even count.", fix: InputFix(title: "Add Leading Zero", replacement: "0" + digits))
        }
        return digits.count <= 40 ? .valid(digits) : .invalid("Keep ITF under 40 digits.")
    }

    private static func msi(_ text: String) -> InputCheck {
        guard let digits = digitsOnly(text) else { return .invalid("MSI uses digits only.") }
        guard digits.count <= 20 else { return .invalid("Keep MSI under 20 digits.") }
        let check = LinearEncoders.msiCheckDigit(digits)
        return .valid(digits + String(check), note: "Check digit \(check) added.")
    }

    private static func pharmacode(_ text: String) -> InputCheck {
        guard let digits = digitsOnly(text), let value = Int(digits) else { return .invalid("Pharmacode is a whole number.") }
        guard (3...131_070).contains(value) else { return .invalid("Pharmacode must be between 3 and 131070.") }
        return .valid(String(value))
    }

    private static func code39(_ text: String) -> InputCheck {
        if text.contains(where: \.isLowercase), text.uppercased().allSatisfy(code39Characters.contains) {
            return .invalid("Code 39 has capital letters only.", fix: InputFix(title: "Use Capitals", replacement: text.uppercased()))
        }
        if let bad = text.first(where: { !code39Characters.contains($0) }) {
            return .invalid("Code 39 can't hold “\(String(bad))”. Use A–Z, 0–9, spaces and - . $ / + %")
        }
        return text.count <= 40 ? .valid(text) : .invalid("Keep Code 39 under 40 characters.")
    }

    private static func codabar(_ text: String) -> InputCheck {
        let upper = text.uppercased()
        let hasGuards = upper.count >= 2 && codabarGuards.contains(upper.first!) && codabarGuards.contains(upper.last!)
        let data = hasGuards ? String(upper.dropFirst().dropLast()) : upper
        if let bad = data.first(where: { !codabarData.contains($0) }) {
            return .invalid("Codabar can't hold “\(String(bad))” here. Use digits and - $ : / . + between the A–D start and stop letters.")
        }
        guard !data.isEmpty else { return .invalid("Add some digits between the start and stop letters.") }
        return hasGuards ? .valid(upper) : .valid("A\(data)A", note: "Start and stop letters A added.")
    }
}

private extension Character {
    nonisolated var isASCIIDigit: Bool { isASCII && isNumber }
}
