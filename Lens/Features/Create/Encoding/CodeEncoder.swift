import Foundation

/// QR error-correction level; raw values are what Core Image expects.
nonisolated enum CorrectionLevel: String, Codable, CaseIterable, Sendable {
    case low = "L", medium = "M", quartile = "Q", high = "H"

    var title: LocalizedStringResource {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .quartile: "Quartile"
        case .high: "High"
        }
    }

    /// Share of the symbol that can be damaged or covered and still decode.
    var recoveryPercent: Int {
        switch self {
        case .low: 7
        case .medium: 15
        case .quartile: 25
        case .high: 30
        }
    }
}

/// One entry point for every format the creator offers. `value` must already be normalised by
/// `SymbologyValidator`; returns `nil` if it still can't be encoded (usually: too long).
nonisolated enum CodeEncoder {
    static func encode(_ value: String, as symbology: Symbology, correction: CorrectionLevel = .medium) -> CodeGraphic? {
        switch symbology {
        case .qr:
            CoreImageEncoder.qr(value, correction: correction).map { .matrix($0, quietZone: 4) }
        case .aztec:
            CoreImageEncoder.aztec(value).map { .matrix($0, quietZone: 2) }
        case .pdf417:
            CoreImageEncoder.pdf417(value).map { .matrix($0, quietZone: 2) }
        case .dataMatrix:
            DataMatrixEncoder.encode(value).map { .matrix($0, quietZone: 2) }
        case .code128:
            CoreImageEncoder.code128(value).map { .linear($0) }
        case .ean13:
            value.count == 13 ? .linear(RetailEncoder.ean13(value)) : nil
        case .ean8:
            value.count == 8 ? .linear(RetailEncoder.ean8(value)) : nil
        case .upcA:
            value.count == 12 ? .linear(RetailEncoder.upcA(value)) : nil
        case .upcE:
            value.count == 8 ? .linear(RetailEncoder.upcE(value)) : nil
        case .code39:
            .linear(LinearEncoders.code39(value))
        case .itf14, .itf:
            value.count.isMultiple(of: 2) ? .linear(LinearEncoders.itf(value)) : nil
        case .msi:
            .linear(LinearEncoders.msi(value))
        case .pharmacode:
            Int(value).map { .linear(LinearEncoders.pharmacode($0)) }
        case .codabar:
            .linear(LinearEncoders.codabar(value))
        case .microQR, .microPDF417, .code93, .gs1DataBar:
            nil
        }
    }
}
