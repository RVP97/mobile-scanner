import CoreGraphics
import Foundation
import Vision

/// Re-reads a rendered code with Vision and measures its contrast, so the studio can promise
/// "Verified" only when the exact payload actually comes back off the pixels.
nonisolated enum ScannabilityChecker {
    struct Report: Hashable, Sendable {
        enum Verdict: Hashable, Sendable {
            case verified
            /// Decodes here, but the colors are close enough that dim light or a cheap camera may not.
            case lowContrast
            /// Light code on a dark background: Lens reads it, many scanners don't.
            case inverted
            case wontScan(Reason)
            /// Vision on this device has no reader for this format (Pharmacode everywhere, MSI before iOS 17).
            case unverifiable
        }

        enum Reason: Hashable, Sendable {
            case lowContrast, inverted, logo, unreadable
        }

        var verdict: Verdict
        /// Ink (lightest stop) against the background, 1…21.
        var contrast: Double
        var duration: Duration
    }

    /// Below this, codes fail in ordinary light; above `comfortableContrast` they're reliable.
    static let minimumContrast = 3.0
    static let comfortableContrast = 4.5
    static let verificationWidth = 900

    static func contrast(for style: CodeStyle) -> (ratio: Double, inverted: Bool) {
        let background = style.backgroundColor ?? .white
        let ink = style.lightestInk.composited(over: background)
        return (RGBAColor.contrast(ink, background), ink.relativeLuminance > background.relativeLuminance)
    }

    /// Renders, decodes and grades the scene. Runs on the concurrent pool, never the main actor.
    @concurrent
    static func check(scene: ArtworkScene, expected: String, symbology: Symbology, style: CodeStyle) async -> Report {
        let clock = ContinuousClock()
        let start = clock.now
        let (ratio, inverted) = contrast(for: style)
        let backdrop = style.backgroundColor ?? .white
        guard let image = SceneRenderer.image(scene, pixelWidth: verificationWidth, backdrop: backdrop) else {
            return Report(verdict: .wontScan(.unreadable), contrast: ratio, duration: .zero)
        }
        guard let payloads = decode(image, symbologies: visionSymbologies(for: symbology)) else {
            return Report(verdict: .unverifiable, contrast: ratio, duration: .zero)
        }
        let decoded = payloads.contains { matches(decoded: $0, expected: expected, symbology: symbology) }
        let duration = clock.now - start

        let verdict: Report.Verdict
        if decoded {
            if inverted {
                verdict = .inverted
            } else if ratio < comfortableContrast {
                verdict = .lowContrast
            } else {
                verdict = .verified
            }
        } else if ratio < minimumContrast {
            verdict = .wontScan(.lowContrast)
        } else if inverted {
            verdict = .wontScan(.inverted)
        } else if style.logo != .none {
            verdict = .wontScan(.logo)
        } else {
            verdict = .wontScan(.unreadable)
        }
        return Report(verdict: verdict, contrast: ratio, duration: duration)
    }

    // MARK: Vision

    /// Payloads Vision finds, or `nil` when this device's Vision can't read any of `symbologies`.
    static func decode(_ image: CGImage, symbologies: [VNBarcodeSymbology]) -> [String]? {
        let request = VNDetectBarcodesRequest()
        #if targetEnvironment(simulator)
        // Newer revisions need the Neural Engine; the simulator only runs revision 2 on the CPU.
        request.revision = 2
        if let cpu = try? request.supportedComputeStageDevices[.main]?.first(where: { if case .cpu = $0 { true } else { false } }) {
            request.setComputeDevice(cpu, for: .main)
        }
        #endif
        let supported = Set((try? request.supportedSymbologies()) ?? [])
        let readable = symbologies.filter(supported.contains)
        guard !readable.isEmpty else { return nil }
        request.symbologies = readable
        do {
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        } catch {
            return []
        }
        return (request.results ?? []).compactMap(\.payloadStringValue)
    }

    static func visionSymbologies(for symbology: Symbology) -> [VNBarcodeSymbology] {
        switch symbology {
        case .qr: [.qr]
        case .microQR: [.microQR]
        case .aztec: [.aztec]
        case .dataMatrix: [.dataMatrix]
        case .pdf417: [.pdf417]
        case .microPDF417: [.microPDF417]
        case .code128: [.code128]
        case .ean13, .upcA: [.ean13]
        case .ean8: [.ean8]
        case .upcE: [.upce]
        case .code39: [.code39, .code39FullASCII]
        case .code93: [.code93]
        case .itf14: [.itf14, .i2of5]
        case .itf: [.i2of5]
        case .codabar: [.codabar]
        case .gs1DataBar: [.gs1DataBar]
        case .msi: [.msiPlessey]
        case .pharmacode: []
        }
    }

    /// Readers differ in whether they report check digits, start/stop letters or UPC-A's leading
    /// zero; accept those representations of the same number, nothing looser.
    static func matches(decoded: String, expected: String, symbology: Symbology) -> Bool {
        if decoded == expected { return true }
        switch symbology {
        case .upcA:
            return decoded == "0" + expected
        case .upcE:
            let middle = String(expected.dropFirst().prefix(6))
            return decoded == String(expected.dropLast()) || decoded == middle || decoded.contains(middle) && decoded.count <= 8
        case .codabar:
            let strip: (String) -> String = { $0.uppercased().trimmingCharacters(in: CharacterSet(charactersIn: "ABCDTN*E")) }
            return strip(decoded) == strip(expected)
        case .msi, .itf14, .itf:
            return decoded == String(expected.dropLast()) || decoded.dropLast() == Substring(expected)
        default:
            return false
        }
    }
}
