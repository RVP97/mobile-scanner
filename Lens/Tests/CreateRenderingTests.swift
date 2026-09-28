import CoreGraphics
import Testing
@testable import Lens

/// Renders our own codes and reads them back with Vision: the same loop the scannability meter runs.
@MainActor
struct CreateRenderingTests {
    nonisolated static let samples: [(Symbology, String)] = [
        (.qr, "https://atlas-coffee.co/menu"),
        (.aztec, "Lens Aztec 42"),
        (.pdf417, "Lens PDF417 sample"),
        (.dataMatrix, "Lens 123456 Data Matrix"),
        (.code128, "LENS-128-abc"),
        (.ean13, "400638133393"),
        (.ean8, "9638507"),
        (.upcA, "03600029145"),
        (.upcE, "0123456"),
        (.code39, "LENS 39"),
        (.itf14, "1234567890123"),
        (.itf, "123456"),
        (.msi, "1234567"),
        (.codabar, "A40156B"),
    ]

    private func report(_ value: String, _ symbology: Symbology, style: CodeStyle = CodeStyle()) async throws -> ScannabilityChecker.Report {
        let normalized = try #require(SymbologyValidator.check(value, for: symbology).value)
        let graphic = try #require(CodeEncoder.encode(normalized, as: symbology, correction: style.effectiveCorrection))
        var geometry: ModuleGeometry?
        if case .matrix(let matrix, _) = graphic, symbology == .qr { geometry = .qr(matrix, style: style) }
        let scene = SceneBuilder.scene(for: SceneInput(graphic: graphic, geometry: geometry, style: style, posterHint: "Point your camera here"))
        return await ScannabilityChecker.check(scene: scene, expected: normalized, symbology: symbology, style: style)
    }

    @Test(arguments: samples.map(\.0))
    func everyFormatDecodesWithVision(_ symbology: Symbology) async throws {
        let value = try #require(Self.samples.first { $0.0 == symbology }?.1)
        let result = try await report(value, symbology)
        #if targetEnvironment(simulator)
        // The simulator's Vision (revision 2) has no MSI reader.
        if symbology == .msi {
            #expect(result.verdict == .unverifiable)
            return
        }
        #endif
        #expect(result.verdict == .verified, "\(symbology.displayName) did not verify")
    }

    @Test func pharmacodeIsUnverifiable() async throws {
        #expect(try await report("1234", .pharmacode).verdict == .unverifiable)
    }

    @Test(arguments: CodeStyle.DotShape.allCases)
    func styledDotsStillScan(_ dots: CodeStyle.DotShape) async throws {
        var style = CodeStyle()
        style.dots = dots
        style.eyeFrame = .leaf
        style.eyePupil = .circle
        #expect(try await report("WIFI:T:WPA;S:Casa Chen;P:correct horse;;", .qr, style: style).verdict == .verified)
    }

    @Test func framedGradientCodeWithInitialsScans() async throws {
        var style = CodeStyle()
        style.apply(palette: CodePalette.named("lagoon")!)
        style.usesGradient = true
        style.logo = .initials("CC")
        style.frame = .badge
        style.caption = "Scan to join Casa Chen"
        #expect(try await report("WIFI:T:WPA;S:Casa Chen;P:correct horse;;", .qr, style: style).verdict == .verified)
    }

    @Test func lowContrastIsFlagged() async throws {
        var style = CodeStyle()
        style.foreground = RGBAColor(hex: 0xE0E0E0)
        let result = try await report("https://lens.app", .qr, style: style)
        #expect(result.contrast < ScannabilityChecker.minimumContrast)
        #expect(result.verdict != .verified)
    }

    // MARK: Contrast math

    @Test func contrastMatchesWCAG() {
        #expect(abs(RGBAColor.contrast(.black, .white) - 21) < 0.001)
        #expect(abs(RGBAColor.contrast(.white, .white) - 1) < 0.001)
        #expect(abs(RGBAColor.contrast(RGBAColor(hex: 0x777777), .white) - 4.48) < 0.01)
        #expect(abs(RGBAColor.contrast(RGBAColor(hex: 0x0071A4), .white) - 5.39) < 0.01)
    }

    @Test func tangerineIsLowContrastOnWhite() {
        var style = CodeStyle()
        style.apply(palette: CodePalette.named("tangerine")!)
        #expect(ScannabilityChecker.contrast(for: style).ratio < ScannabilityChecker.minimumContrast)
    }

    @Test func invertedColorsAreDetected() {
        var style = CodeStyle()
        style.foreground = .white
        style.background = .tinted  // tint of white is white → still flagged as no contrast
        #expect(ScannabilityChecker.contrast(for: style).ratio < 1.1)
    }

    // MARK: Exports

    @Test func svgContainsVectorPaths() throws {
        let scene = try #require(CodeRenderer.plainScene(raw: "Lens", symbology: .qr))
        let svg = SVGExporter.svg(scene)
        #expect(svg.hasPrefix("<?xml"))
        #expect(svg.contains("<path d=\"M"))
        #expect(svg.contains("fill=\"#000000\""))
    }

    @Test func pdfIsProduced() throws {
        let scene = try #require(CodeRenderer.plainScene(raw: "Lens", symbology: .ean13))
        let pdf = SceneRenderer.pdfData(scene)
        #expect(pdf.starts(with: Array("%PDF".utf8)))
    }

    @Test func plainImageForNonGeneratableFormat() {
        #expect(CodeRenderer.image(raw: "LENS93", symbology: .code93, dimension: 200) != nil)
    }
}
