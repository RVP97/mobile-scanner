import Foundation
import Vision

/// Decodes every code in a still image with Vision. The detection runs off the main actor.
enum BarcodeImageReader {
    static func codes(in imageData: Data) async throws -> [ScannedCode] {
        let found = try await detect(in: imageData)
        return found.compactMap { raw, vision in
            Symbology(vision: vision, payload: raw).map { ScannedCode(raw: raw, symbology: $0) }
        }
    }

    @concurrent
    private nonisolated static func detect(in imageData: Data) async throws -> [(String, VNBarcodeSymbology)] {
        let request = VNDetectBarcodesRequest()
        do {
            try VNImageRequestHandler(data: imageData).perform([request])
        } catch {
            throw ScanImageError.unreadableImage
        }
        return (request.results ?? []).compactMap { observation in
            observation.payloadStringValue.map { ($0, observation.symbology) }
        }
    }
}
