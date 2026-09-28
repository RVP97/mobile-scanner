import AVFoundation
import Vision

/// The physical format of a code. Covers everything we can read and everything we can make.
enum Symbology: String, Codable, CaseIterable, Identifiable, Sendable {
    case qr
    case microQR
    case aztec
    case dataMatrix
    case pdf417
    case microPDF417
    case ean13
    case ean8
    case upcA
    case upcE
    case code128
    case code39
    case code93
    case itf14
    case itf
    case codabar
    case gs1DataBar
    case msi
    case pharmacode

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qr: String(localized: "QR Code")
        case .microQR: "Micro QR"
        case .aztec: "Aztec"
        case .dataMatrix: "Data Matrix"
        case .pdf417: "PDF417"
        case .microPDF417: "MicroPDF417"
        case .ean13: "EAN-13"
        case .ean8: "EAN-8"
        case .upcA: "UPC-A"
        case .upcE: "UPC-E"
        case .code128: "Code 128"
        case .code39: "Code 39"
        case .code93: "Code 93"
        case .itf14: "ITF-14"
        case .itf: "ITF"
        case .codabar: "Codabar"
        case .gs1DataBar: "GS1 DataBar"
        case .msi: "MSI"
        case .pharmacode: "Pharmacode"
        }
    }

    var isTwoDimensional: Bool {
        switch self {
        case .qr, .microQR, .aztec, .dataMatrix, .pdf417, .microPDF417: true
        default: false
        }
    }

    /// Formats offered in the creator, in picker order.
    static let generatable: [Symbology] = [
        .qr, .aztec, .pdf417, .dataMatrix, .code128, .ean13, .ean8, .upcA, .upcE,
        .code39, .itf14, .itf, .msi, .pharmacode, .codabar,
    ]

    /// Retail formats whose payload is a product number worth looking up.
    var isRetail: Bool { [.ean13, .ean8, .upcA, .upcE].contains(self) }

    // MARK: Live camera (AVFoundation)

    static let captureTypes: [AVMetadataObject.ObjectType] = [
        .qr, .microQR, .aztec, .dataMatrix, .pdf417, .microPDF417,
        .ean13, .ean8, .upce, .code128, .code39, .code39Mod43, .code93,
        .itf14, .interleaved2of5, .codabar, .gs1DataBar, .gs1DataBarExpanded, .gs1DataBarLimited,
    ]

    init?(metadataType: AVMetadataObject.ObjectType, payload: String) {
        switch metadataType {
        case .qr: self = .qr
        case .microQR: self = .microQR
        case .aztec: self = .aztec
        case .dataMatrix: self = .dataMatrix
        case .pdf417: self = .pdf417
        case .microPDF417: self = .microPDF417
        // AVFoundation reports UPC-A as EAN-13 with a leading zero.
        case .ean13: self = payload.count == 13 && payload.hasPrefix("0") ? .upcA : .ean13
        case .ean8: self = .ean8
        case .upce: self = .upcE
        case .code128: self = .code128
        case .code39, .code39Mod43: self = .code39
        case .code93: self = .code93
        case .itf14: self = .itf14
        case .interleaved2of5: self = .itf
        case .codabar: self = .codabar
        case .gs1DataBar, .gs1DataBarExpanded, .gs1DataBarLimited: self = .gs1DataBar
        default: return nil
        }
    }

    // MARK: Still images (Vision)

    init?(vision: VNBarcodeSymbology, payload: String) {
        switch vision {
        case .qr: self = .qr
        case .microQR: self = .microQR
        case .aztec: self = .aztec
        case .dataMatrix: self = .dataMatrix
        case .pdf417: self = .pdf417
        case .microPDF417: self = .microPDF417
        case .ean13: self = payload.count == 13 && payload.hasPrefix("0") ? .upcA : .ean13
        case .ean8: self = .ean8
        case .upce: self = .upcE
        case .code128: self = .code128
        case .code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum: self = .code39
        case .code93, .code93i: self = .code93
        case .itf14: self = .itf14
        case .i2of5, .i2of5Checksum: self = .itf
        case .codabar: self = .codabar
        case .gs1DataBar, .gs1DataBarExpanded, .gs1DataBarLimited: self = .gs1DataBar
        default: return nil
        }
    }
}
