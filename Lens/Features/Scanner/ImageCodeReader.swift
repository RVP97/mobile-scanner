import CoreTransferable
import ImageIO
import UniformTypeIdentifiers
import Vision

/// Finds every code in a still image (Photos, drag and drop, paste) with Vision.
nonisolated enum ImageCodeReader {
    struct Detection: Hashable, Sendable {
        var payload: String
        /// `VNBarcodeSymbology` raw value.
        var symbology: String
    }

    enum Failure: Error {
        case unreadableImage
    }

    /// Codes in reading order (top to bottom), one per distinct payload.
    @concurrent
    static func detections(in data: Data) async throws -> [Detection] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw Failure.unreadableImage
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = (properties?[kCGImagePropertyOrientation] as? UInt32)
            .flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up

        let request = VNDetectBarcodesRequest()
        #if targetEnvironment(simulator)
        // The current barcode model can't run in Simulator; the first revision (classic detector) can.
        request.revision = 1
        #endif
        request.symbologies = try request.supportedSymbologies()
        try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])

        var seen = Set<String>()
        return (request.results ?? [])
            .sorted { $0.boundingBox.midY > $1.boundingBox.midY }
            .compactMap { observation -> Detection? in
                guard let payload = observation.payloadStringValue, !payload.isEmpty,
                      seen.insert(payload).inserted else { return nil }
                return Detection(payload: payload, symbology: observation.symbology.rawValue)
            }
    }

    @MainActor
    static func codes(in data: Data) async throws -> [ScannedCode] {
        try await detections(in: data).compactMap { detection in
            Symbology(vision: VNBarcodeSymbology(rawValue: detection.symbology), payload: detection.payload)
                .map { ScannedCode(raw: detection.payload, symbology: $0) }
        }
    }
}

/// An image dropped onto the scanner.
nonisolated struct DroppedImage: Transferable {
    var data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { DroppedImage(data: $0) }
    }
}
