import CoreGraphics
import Testing
@testable import Lens

/// Bit patterns and check digits against published reference values.
struct CreateEncoderTests {
    private func bits(_ barcode: LinearBarcode) -> String {
        String(barcode.modules.map { $0 ? "1" : "0" })
    }

    // MARK: Check digits

    @Test(arguments: [
        ("400638133393", 1),   // EAN-13 4006381333931
        ("590123412345", 7),   // EAN-13 5901234123457
        ("9638507", 4),        // EAN-8 96385074
        ("03600029145", 2),    // UPC-A 036000291452
        ("1234567890123", 1),  // ITF-14 12345678901231
    ])
    func gtinCheckDigit(body: String, expected: Int) {
        #expect(RetailEncoder.checkDigit(for: body) == expected)
    }

    @Test func msiCheckDigitIsLuhn() {
        #expect(LinearEncoders.msiCheckDigit("1234567") == 4)
        #expect(LinearEncoders.msiCheckDigit("80523") == 4)
    }

    // MARK: Retail patterns

    @Test func ean13ReferencePattern() {
        let symbol = RetailEncoder.ean13("4006381333931")
        #expect(symbol.modules.count == 95)
        // Start guard, then "0" in L, "0" in G, "6" in G… (leading 4 → LGLLGG).
        #expect(bits(symbol).hasPrefix("101" + "0001101" + "0100111" + "0101111"))
        #expect(String(bits(symbol).dropFirst(45).prefix(5)) == "01010")
        #expect(symbol.text.map(\.text).joined() == "4006381333931")
    }

    @Test func ean13RightHalfUsesRCodes() {
        let symbol = RetailEncoder.ean13("4006381333931")
        let right = String(bits(symbol).dropFirst(50).prefix(42))
        #expect(right == "1000010" + "1000010" + "1000010" + "1110100" + "1000010" + "1100110")
    }

    @Test func ean8ReferencePattern() {
        let symbol = RetailEncoder.ean8("96385074")
        #expect(symbol.modules.count == 67)
        #expect(bits(symbol) == "101" + "0001011" + "0101111" + "0111101" + "0110111"
            + "01010" + "1001110" + "1110010" + "1000100" + "1011100" + "101")
    }

    @Test func upcAIsEAN13WithLeadingZero() {
        #expect(RetailEncoder.upcA("036000291452").modules == RetailEncoder.ean13("0036000291452").modules)
    }

    @Test func upcEParityFollowsCheckDigit() {
        let symbol = RetailEncoder.upcE("01234565")
        #expect(symbol.modules.count == 51)
        // Check digit 5, number system 0 → G L L G G L.
        #expect(bits(symbol) == "101" + "0110011" + "0010011" + "0111101" + "0011101" + "0111001" + "0101111" + "010101")
    }

    @Test func upcEExpandsAndCompresses() {
        #expect(RetailEncoder.expandUPCE(numberSystem: 0, [1, 2, 3, 4, 5, 6]) == [0, 1, 2, 3, 4, 5, 0, 0, 0, 0, 6])
        #expect(RetailEncoder.compressUPCA("012345000065") == "01234565")
        #expect(RetailEncoder.compressUPCA("036000291452") == nil)
    }

    // MARK: Other 1-D

    @Test func code39WrapsInAsterisks() {
        let symbol = LinearEncoders.code39("A")
        // * A * = three 9-element characters (3 wide each) + 2 gaps.
        #expect(symbol.modules.count == 3 * (6 + 3 * 3) + 2)
        #expect(bits(symbol).hasPrefix("1000101110111010"))  // "*" = n w n n w n w n n
    }

    @Test func pharmacodeBars() {
        #expect(bits(LinearEncoders.pharmacode(3)) == "1001")
        #expect(bits(LinearEncoders.pharmacode(4)) == "100111")      // narrow (2) + wide (2)
        #expect(LinearEncoders.pharmacode(131_070).bars.count == 16)
        #expect(LinearEncoders.pharmacode(131_070).bars.allSatisfy { $0.length == 3 })
    }

    @Test func itfInterleavesPairs() {
        let symbol = LinearEncoders.itf("12")
        // start 1010, pair (1 bars wnnnw, 2 spaces nwnnw), stop 111 0 1
        #expect(bits(symbol) == "1010" + "111" + "0" + "1" + "000" + "1" + "0" + "1" + "0" + "111" + "000" + "11101")
    }

    @Test func msiPattern() {
        #expect(bits(LinearEncoders.msi("1")) == "110" + "100100100110" + "1001")
    }

    @Test func codabarStartsAndEndsWithGuards() {
        let symbol = LinearEncoders.codabar("A1234B")
        #expect(symbol.text.first?.text == "1234")
        // A = n n w w n w n, then the inter-character gap.
        #expect(bits(symbol).hasPrefix("10111000100010"))
    }

    // MARK: Data Matrix

    @Test func dataMatrixReferenceCodewords() {
        let data = DataMatrixEncoder.dataCodewords(for: "123456")
        #expect(data == [142, 164, 186])
        let size = DataMatrixEncoder.sizes[0]
        #expect(DataMatrixEncoder.codewords(data: data, size: size) == [142, 164, 186, 114, 25, 5, 88, 102])
    }

    @Test func dataMatrixPadding() {
        // "A" → 66, then pad 129, then randomised pads.
        #expect(DataMatrixEncoder.pad([66], to: 3) == [66, 129, 70])
    }

    @Test func dataMatrixFinderPattern() throws {
        let matrix = try #require(DataMatrixEncoder.encode("Lens"))
        #expect(matrix.width == 12)
        for i in 0..<12 {
            #expect(matrix[i, 0])                    // solid left edge
            #expect(matrix[11, i])                   // solid bottom edge
            #expect(matrix[0, i] == i.isMultiple(of: 2))  // top clock track
        }
    }

    // MARK: QR extraction

    @Test func qrMatrixIsTrimmedToSymbol() throws {
        let matrix = try #require(CoreImageEncoder.qr("Lens", correction: .medium))
        #expect(matrix.width == 21)
        #expect(matrix.height == 21)
        // Finder pattern: dark ring, light ring, dark 3×3 centre.
        for (row, column) in [(0, 0), (0, 14), (14, 0)] {
            #expect(matrix[row, column] && matrix[row + 6, column + 6])
            #expect(!matrix[row + 1, column + 1])
            #expect(matrix[row + 3, column + 3])
        }
    }

    @Test func correctionLevelGrowsTheSymbol() throws {
        let text = String(repeating: "lens ", count: 12)
        let low = try #require(CoreImageEncoder.qr(text, correction: .low))
        let high = try #require(CoreImageEncoder.qr(text, correction: .high))
        #expect(high.width > low.width)
    }
}
