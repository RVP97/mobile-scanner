import Foundation

/// ECC 200 Data Matrix (ISO/IEC 16022), square symbols 10×10 to 144×144, ASCII encodation.
nonisolated enum DataMatrixEncoder {
    struct SymbolSize: Sendable {
        let size: Int
        /// Data region edge (excluding finder and clock track).
        let region: Int
        let dataCodewords: Int
        let eccCodewords: Int
        let blocks: Int

        var regionsPerSide: Int { size / (region + 2) }
    }

    static let sizes: [SymbolSize] = [
        .init(size: 10, region: 8, dataCodewords: 3, eccCodewords: 5, blocks: 1),
        .init(size: 12, region: 10, dataCodewords: 5, eccCodewords: 7, blocks: 1),
        .init(size: 14, region: 12, dataCodewords: 8, eccCodewords: 10, blocks: 1),
        .init(size: 16, region: 14, dataCodewords: 12, eccCodewords: 12, blocks: 1),
        .init(size: 18, region: 16, dataCodewords: 18, eccCodewords: 14, blocks: 1),
        .init(size: 20, region: 18, dataCodewords: 22, eccCodewords: 18, blocks: 1),
        .init(size: 22, region: 20, dataCodewords: 30, eccCodewords: 20, blocks: 1),
        .init(size: 24, region: 22, dataCodewords: 36, eccCodewords: 24, blocks: 1),
        .init(size: 26, region: 24, dataCodewords: 44, eccCodewords: 28, blocks: 1),
        .init(size: 32, region: 14, dataCodewords: 62, eccCodewords: 36, blocks: 1),
        .init(size: 36, region: 16, dataCodewords: 86, eccCodewords: 42, blocks: 1),
        .init(size: 40, region: 18, dataCodewords: 114, eccCodewords: 48, blocks: 1),
        .init(size: 44, region: 20, dataCodewords: 144, eccCodewords: 56, blocks: 1),
        .init(size: 48, region: 22, dataCodewords: 174, eccCodewords: 68, blocks: 1),
        .init(size: 52, region: 24, dataCodewords: 204, eccCodewords: 84, blocks: 2),
        .init(size: 64, region: 14, dataCodewords: 280, eccCodewords: 112, blocks: 2),
        .init(size: 72, region: 16, dataCodewords: 368, eccCodewords: 144, blocks: 4),
        .init(size: 80, region: 18, dataCodewords: 456, eccCodewords: 192, blocks: 4),
        .init(size: 88, region: 20, dataCodewords: 576, eccCodewords: 224, blocks: 4),
        .init(size: 96, region: 22, dataCodewords: 696, eccCodewords: 272, blocks: 4),
        .init(size: 104, region: 24, dataCodewords: 816, eccCodewords: 336, blocks: 6),
        .init(size: 120, region: 18, dataCodewords: 1050, eccCodewords: 408, blocks: 6),
        .init(size: 132, region: 20, dataCodewords: 1304, eccCodewords: 496, blocks: 8),
        .init(size: 144, region: 22, dataCodewords: 1558, eccCodewords: 620, blocks: 10),
    ]

    static var maximumDataCodewords: Int { sizes.last!.dataCodewords }

    // MARK: Encodation

    /// ASCII encodation: digit pairs pack into one codeword, bytes above 127 use Upper Shift.
    /// Text that isn't Latin-1 is sent as UTF-8 behind ECI 000026.
    static func dataCodewords(for text: String) -> [UInt8] {
        var output: [UInt8] = []
        let bytes: [UInt8]
        if let latin1 = text.data(using: .isoLatin1) {
            bytes = Array(latin1)
        } else {
            output += [241, 27]
            bytes = Array(text.utf8)
        }
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            if isDigit(byte), index + 1 < bytes.count, isDigit(bytes[index + 1]) {
                output.append(UInt8(130 + Int(byte - 48) * 10 + Int(bytes[index + 1] - 48)))
                index += 2
            } else if byte < 128 {
                output.append(byte + 1)
                index += 1
            } else {
                output += [235, byte - 127]
                index += 1
            }
        }
        return output
    }

    private static func isDigit(_ byte: UInt8) -> Bool { byte >= 48 && byte <= 57 }

    /// Pads `data` to the symbol's capacity with 129 then the 253-state randomised pad.
    static func pad(_ data: [UInt8], to capacity: Int) -> [UInt8] {
        var result = data
        if result.count < capacity { result.append(129) }
        while result.count < capacity {
            let position = result.count + 1
            let pseudoRandom = (149 * position) % 253 + 1
            var value = 129 + pseudoRandom
            if value > 254 { value -= 254 }
            result.append(UInt8(value))
        }
        return result
    }

    /// Data + interleaved Reed–Solomon codewords for `size`.
    static func codewords(data: [UInt8], size: SymbolSize) -> [UInt8] {
        let padded = pad(data, to: size.dataCodewords)
        let eccPerBlock = size.eccCodewords / size.blocks
        var result = padded + Array(repeating: 0, count: size.eccCodewords)
        for block in 0..<size.blocks {
            let blockData = stride(from: block, to: padded.count, by: size.blocks).map { padded[$0] }
            let ecc = ReedSolomon.dataMatrix.ecc(for: blockData, count: eccPerBlock)
            for (j, codeword) in ecc.enumerated() {
                result[size.dataCodewords + block + j * size.blocks] = codeword
            }
        }
        return result
    }

    /// `nil` when the text is longer than the largest symbol holds.
    static func encode(_ text: String) -> BitMatrix? {
        let data = dataCodewords(for: text)
        guard let size = sizes.first(where: { $0.dataCodewords >= data.count }) else { return nil }
        return matrix(codewords: codewords(data: data, size: size), size: size)
    }

    // MARK: Module placement (ISO/IEC 16022 Annex F)

    static func matrix(codewords: [UInt8], size: SymbolSize) -> BitMatrix {
        let mappingSide = size.region * size.regionsPerSide
        var placement = Placement(rows: mappingSide, columns: mappingSide)
        placement.run()

        var symbol = BitMatrix(width: size.size, height: size.size)
        let step = size.region + 2
        // Finder "L" and clock tracks around every data region.
        for regionRow in 0..<size.regionsPerSide {
            for regionColumn in 0..<size.regionsPerSide {
                let top = regionRow * step, left = regionColumn * step
                for i in 0..<step {
                    symbol[top + i, left] = true                                   // left edge
                    symbol[top + step - 1, left + i] = true                        // bottom edge
                    symbol[top, left + i] = i.isMultiple(of: 2)                    // top clock
                    symbol[top + i, left + step - 1] = !i.isMultiple(of: 2)        // right clock
                }
            }
        }
        for row in 0..<mappingSide {
            for column in 0..<mappingSide {
                let value = placement.cells[row * mappingSide + column]
                let isDark: Bool
                if value == Placement.fixedDark {
                    isDark = true
                } else if value >= 10 {
                    let codeword = codewords[value / 10 - 1]
                    isDark = codeword & (1 << (8 - value % 10)) != 0
                } else {
                    isDark = false
                }
                let symbolRow = (row / size.region) * step + 1 + row % size.region
                let symbolColumn = (column / size.region) * step + 1 + column % size.region
                symbol[symbolRow, symbolColumn] = isDark
            }
        }
        return symbol
    }

    /// The "utah" diagonal placement. Cells hold `codeword * 10 + bit` (bit 1 = MSB), 0 for unset.
    private struct Placement {
        static let fixedDark = 1
        let rows: Int
        let columns: Int
        var cells: [Int]

        init(rows: Int, columns: Int) {
            self.rows = rows
            self.columns = columns
            cells = Array(repeating: 0, count: rows * columns)
        }

        mutating func module(_ row: Int, _ column: Int, _ codeword: Int, _ bit: Int) {
            var row = row, column = column
            if row < 0 {
                row += rows
                column += 4 - ((rows + 4) % 8)
            }
            if column < 0 {
                column += columns
                row += 4 - ((columns + 4) % 8)
            }
            cells[row * columns + column] = codeword * 10 + bit
        }

        mutating func utah(_ row: Int, _ column: Int, _ codeword: Int) {
            module(row - 2, column - 2, codeword, 1)
            module(row - 2, column - 1, codeword, 2)
            module(row - 1, column - 2, codeword, 3)
            module(row - 1, column - 1, codeword, 4)
            module(row - 1, column, codeword, 5)
            module(row, column - 2, codeword, 6)
            module(row, column - 1, codeword, 7)
            module(row, column, codeword, 8)
        }

        mutating func corner(_ positions: [(Int, Int)], _ codeword: Int) {
            for (bit, position) in positions.enumerated() {
                module(position.0, position.1, codeword, bit + 1)
            }
        }

        mutating func run() {
            let r = rows, c = columns
            var codeword = 1, row = 4, column = 0
            repeat {
                if row == r, column == 0 {
                    corner([(r - 1, 0), (r - 1, 1), (r - 1, 2), (0, c - 2), (0, c - 1), (1, c - 1), (2, c - 1), (3, c - 1)], codeword)
                    codeword += 1
                }
                if row == r - 2, column == 0, c % 4 != 0 {
                    corner([(r - 3, 0), (r - 2, 0), (r - 1, 0), (0, c - 4), (0, c - 3), (0, c - 2), (0, c - 1), (1, c - 1)], codeword)
                    codeword += 1
                }
                if row == r - 2, column == 0, c % 8 == 4 {
                    corner([(r - 3, 0), (r - 2, 0), (r - 1, 0), (0, c - 2), (0, c - 1), (1, c - 1), (2, c - 1), (3, c - 1)], codeword)
                    codeword += 1
                }
                if row == r + 4, column == 2, c % 8 == 0 {
                    corner([(r - 1, 0), (r - 1, c - 1), (0, c - 3), (0, c - 2), (0, c - 1), (1, c - 3), (1, c - 2), (1, c - 1)], codeword)
                    codeword += 1
                }
                repeat {
                    if row < r, column >= 0, cells[row * c + column] == 0 {
                        utah(row, column, codeword)
                        codeword += 1
                    }
                    row -= 2
                    column += 2
                } while row >= 0 && column < c
                row += 1
                column += 3
                repeat {
                    if row >= 0, column < c, cells[row * c + column] == 0 {
                        utah(row, column, codeword)
                        codeword += 1
                    }
                    row += 2
                    column -= 2
                } while row < r && column >= 0
                row += 3
                column += 1
            } while row < r || column < c

            if cells[r * c - 1] == 0 {
                cells[r * c - 1] = Self.fixedDark
                cells[r * c - c - 2] = Self.fixedDark
            }
        }
    }
}
