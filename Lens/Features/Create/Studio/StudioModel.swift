import SwiftData
import SwiftUI

/// Tools in the studio's bottom panel.
enum StudioTool: String, CaseIterable, Identifiable {
    case dots, corners, color, logo, frame

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .dots: "Dots"
        case .corners: "Corners"
        case .color: "Color"
        case .logo: "Logo"
        case .frame: "Frame"
        }
    }
}

/// The styled code being made. Encoding and module geometry are cached and only rebuilt when
/// something that affects them changes, so color drags just repaint.
@Observable
final class StudioModel {
    let document: CodeDocument

    var style: CodeStyle {
        didSet { styleDidChange(from: oldValue) }
    }

    var tool: StudioTool

    private(set) var graphic: CodeGraphic?
    private(set) var geometry: ModuleGeometry?
    private(set) var logoImage: CGImage?
    /// The finished artwork, rebuilt once per style change and shared by preview, meter and exports.
    private(set) var scene: ArtworkScene?
    private(set) var report: ScannabilityChecker.Report?
    private(set) var isChecking = false
    /// History entry for this code, created on the first save/share/print and updated after.
    @ObservationIgnored private var record: ScanRecord?
    @ObservationIgnored var modelContext: ModelContext?

    init(document: CodeDocument, style: CodeStyle = CodeStyle()) {
        self.document = document
        var style = style
        if style == CodeStyle(), document.symbology == .qr, document.kind == .wifi {
            // Wi-Fi signs traditionally show the network glyph; start there.
            style.logo = .kindGlyph
        }
        if style.caption.isEmpty { style.caption = document.caption }
        self.style = style
        tool = document.symbology == .qr ? .dots : .color
        encode()
        rebuildGeometry()
        rebuildLogo()
        rebuildScene()
    }

    var isQR: Bool { document.symbology == .qr }
    var isLinear: Bool { !document.symbology.isTwoDimensional }

    var tools: [StudioTool] {
        isQR ? StudioTool.allCases : [.color, .frame]
    }

    /// Side of the QR symbol in modules, for the density note.
    var moduleCount: Int? {
        if case .matrix(let matrix, _) = graphic { matrix.width } else { nil }
    }


    // MARK: Caching

    private func styleDidChange(from old: CodeStyle) {
        if old.effectiveCorrection != style.effectiveCorrection { encode() }
        if old.dots != style.dots || old.eyeFrame != style.eyeFrame || old.eyePupil != style.eyePupil
            || (old.logo == .none) != (style.logo == .none) || old.effectiveCorrection != style.effectiveCorrection {
            rebuildGeometry()
        }
        if old.logo != style.logo { rebuildLogo() }
        rebuildScene()
    }

    private func rebuildScene() {
        guard let graphic else {
            scene = nil
            return
        }
        scene = SceneBuilder.scene(for: SceneInput(
            graphic: graphic, geometry: geometry, style: style, logoImage: logoImage,
            posterHint: String(localized: "Point your camera at the code")
        ))
    }

    private func encode() {
        graphic = CodeEncoder.encode(document.raw, as: document.symbology, correction: style.effectiveCorrection)
    }

    private func rebuildGeometry() {
        guard case .matrix(let matrix, _) = graphic else {
            geometry = nil
            return
        }
        geometry = isQR ? .qr(matrix, style: style) : .plain(matrix)
    }

    private func rebuildLogo() {
        switch style.logo {
        case .kindGlyph: logoImage = LogoImages.glyphMask(document.kind.symbol)
        case .photo(let data, _): logoImage = LogoImages.decode(data)
        case .none, .initials: logoImage = nil
        }
    }

    // MARK: Verification

    struct VerificationKey: Hashable {
        var style: CodeStyle
        var raw: String
    }

    var verificationKey: VerificationKey { VerificationKey(style: style, raw: document.raw) }

    /// Debounced by the caller (`task(id:)`); a newer change cancels the older check.
    func verify() async {
        guard let scene else { return }
        isChecking = true
        let result = await ScannabilityChecker.check(scene: scene, expected: document.raw, symbology: document.symbology, style: style)
        guard !Task.isCancelled else { return }
        report = result
        isChecking = false
    }

    // MARK: History

    /// Saves (or updates) the History entry for this code with the current style.
    func recordCreation() {
        guard let context = modelContext else { return }
        if let record {
            record.styleData = style.encoded()
        } else {
            record = RecordWriter.save(document.scanResult, origin: .created, style: style.encoded(), in: context)
        }
        try? context.save()
    }
}
