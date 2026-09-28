import CoreImage.CIFilterBuiltins
import Foundation
import Testing
import UIKit
@testable import Lens

struct ScannerImageReaderTests {
    /// A QR code on a white canvas with a generous quiet zone, as PNG.
    private func qrPNG(_ message: String) throws -> Data {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(message.utf8)
        filter.correctionLevel = "M"
        let output = try #require(filter.outputImage)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let cgImage = try #require(CIContext().createCGImage(scaled, from: scaled.extent))
        let side = scaled.extent.width + 160
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            UIImage(cgImage: cgImage).draw(in: CGRect(x: 80, y: 80, width: scaled.extent.width, height: scaled.extent.height))
        }
        return try #require(image.pngData())
    }

    @Test func readsAQRCodeFromAnImage() async throws {
        let codes = try await ImageCodeReader.codes(in: qrPNG("https://atlas-coffee.co/menu"))
        #expect(codes.map(\.raw) == ["https://atlas-coffee.co/menu"])
        #expect(codes.first?.symbology == .qr)
    }

    @Test func blankImageHasNoCodes() async throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        }
        let codes = try await ImageCodeReader.codes(in: try #require(blank.pngData()))
        #expect(codes.isEmpty)
    }

    @Test func garbageDataThrows() async {
        await #expect(throws: ImageCodeReader.Failure.self) {
            _ = try await ImageCodeReader.codes(in: Data("not an image".utf8))
        }
    }
}
