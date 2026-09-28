import CoreImage.CIFilterBuiltins

/// The dark modules of a real QR code, as a square grid (quiet zone removed).
struct QRMatrix {
    let size: Int
    private let modules: [Bool]

    init?(_ text: String) {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "L"
        guard let image = filter.outputImage else { return nil }
        let width = Int(image.extent.width)
        var pixels = [UInt8](repeating: 255, count: width * width)
        let context = CIContext()
        context.render(
            image,
            toBitmap: &pixels,
            rowBytes: width,
            bounds: image.extent,
            format: .L8,
            colorSpace: CGColorSpaceCreateDeviceGray()
        )
        // Core Image pads the symbol with a quiet zone; trim to the finder patterns.
        let dark = pixels.map { $0 < 128 }
        let rows = (0..<width).filter { row in (0..<width).contains { dark[row * width + $0] } }
        guard let first = rows.first, let last = rows.last else { return nil }
        size = last - first + 1
        modules = (first...last).flatMap { row in (first...last).map { dark[row * width + $0] } }
    }

    func isDark(row: Int, column: Int) -> Bool {
        modules[row * size + column]
    }
}
