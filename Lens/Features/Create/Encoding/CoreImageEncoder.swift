import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// QR, Aztec, PDF417 and Code 128 via Core Image's generators, read back one pixel per module.
nonisolated enum CoreImageEncoder {
    private static let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])

    /// The QR symbol only (quiet zone trimmed), so finder patterns sit at the matrix corners.
    static func qr(_ text: String, correction: CorrectionLevel) -> BitMatrix? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = correction.rawValue
        guard let output = filter.outputImage, let pixels = pixelMatrix(output) else { return nil }
        return trimmed(pixels)
    }

    static func aztec(_ text: String) -> BitMatrix? {
        let filter = CIFilter.aztecCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = 33
        guard let output = filter.outputImage else { return nil }
        return pixelMatrix(output).map(trimmed)
    }

    static func pdf417(_ text: String) -> BitMatrix? {
        let filter = CIFilter.pdf417BarcodeGenerator()
        filter.message = Data(text.utf8)
        guard let output = filter.outputImage else { return nil }
        return pixelMatrix(output).map(trimmed)
    }

    /// Core Image only takes ASCII for Code 128.
    static func code128(_ text: String) -> LinearBarcode? {
        guard let data = text.data(using: .ascii) else { return nil }
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = data
        filter.quietSpace = 0
        filter.barcodeHeight = 1
        guard let output = filter.outputImage, let pixels = pixelMatrix(output), pixels.height > 0 else { return nil }
        let modules = (0..<pixels.width).map { pixels[0, $0] }
        return LinearBarcode(modules: modules, text: LinearBarcode.centeredText(text, over: modules.count))
    }

    // MARK: Pixel readback

    /// Renders a generator's output 1:1 into 8-bit gray and thresholds it.
    static func pixelMatrix(_ image: CIImage) -> BitMatrix? {
        let extent = image.extent.integral
        let width = Int(extent.width), height = Int(extent.height)
        guard width > 0, height > 0, width * height < 4_000_000 else { return nil }
        var bytes = [UInt8](repeating: 255, count: width * height)
        bytes.withUnsafeMutableBytes { buffer in
            context.render(
                image,
                toBitmap: buffer.baseAddress!,
                rowBytes: width,
                bounds: extent,
                format: .L8,
                colorSpace: nil
            )
        }
        return BitMatrix(width: width, height: height, cells: bytes.map { $0 < 128 })
    }

    /// Crops to the bounding box of dark cells (drops the generator's own quiet zone).
    static func trimmed(_ matrix: BitMatrix) -> BitMatrix {
        var top = matrix.height, bottom = -1, left = matrix.width, right = -1
        for row in 0..<matrix.height {
            for column in 0..<matrix.width where matrix[row, column] {
                top = min(top, row)
                bottom = max(bottom, row)
                left = min(left, column)
                right = max(right, column)
            }
        }
        guard bottom >= top, right >= left else { return matrix }
        let width = right - left + 1, height = bottom - top + 1
        var result = BitMatrix(width: width, height: height)
        for row in 0..<height {
            for column in 0..<width {
                result[row, column] = matrix[row + top, column + left]
            }
        }
        return result
    }
}
