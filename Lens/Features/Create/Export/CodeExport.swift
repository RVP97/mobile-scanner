import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// File formats a finished code can leave the app in.
nonisolated protocol CodeExportFormat: Sendable {
    static var contentType: UTType { get }
    static func data(for scene: ArtworkScene) -> Data
}

nonisolated enum PNGFormat: CodeExportFormat {
    /// Big enough for print at ~17 cm and 300 dpi, small enough to message.
    static let pixelWidth = 2048
    static var contentType: UTType { .png }
    static func data(for scene: ArtworkScene) -> Data { SceneRenderer.pngData(scene, pixelWidth: pixelWidth) ?? Data() }
}

nonisolated enum PDFFormat: CodeExportFormat {
    static var contentType: UTType { .pdf }
    static func data(for scene: ArtworkScene) -> Data { SceneRenderer.pdfData(scene, pointWidth: 360) }
}

nonisolated enum SVGFormat: CodeExportFormat {
    static var contentType: UTType { .svg }
    static func data(for scene: ArtworkScene) -> Data { Data(SVGExporter.svg(scene).utf8) }
}

/// A lazily rendered export for `ShareLink`: nothing is drawn until the share sheet asks for it.
struct CodeExport<Format: CodeExportFormat>: Transferable, Sendable {
    var scene: ArtworkScene
    var fileName: String
    /// Runs when the file is actually produced (records the code in History).
    var onExport: @MainActor @Sendable () -> Void

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: Format.contentType) { export in
            await export.onExport()
            return await render(export.scene)
        }
        .suggestedFileName { $0.fileName }
    }

    @concurrent
    private static func render(_ scene: ArtworkScene) async -> Data {
        Format.data(for: scene)
    }
}

/// Off-main rendering for the non-share actions.
nonisolated enum ExportRenderer {
    @concurrent
    static func png(_ scene: ArtworkScene) async -> Data {
        PNGFormat.data(for: scene)
    }

    @concurrent
    static func pdf(_ scene: ArtworkScene) async -> Data {
        PDFFormat.data(for: scene)
    }
}
