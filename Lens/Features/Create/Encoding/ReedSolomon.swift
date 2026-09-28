import Foundation

/// Reed–Solomon error correction over GF(256).
nonisolated struct ReedSolomon: Sendable {
    /// Data Matrix field: x⁸ + x⁵ + x³ + x² + 1, generator roots α¹…αⁿ.
    static let dataMatrix = ReedSolomon(primitive: 0x12D, firstRoot: 1)

    private let exp: [Int]
    private let log: [Int]
    private let firstRoot: Int

    init(primitive: Int, firstRoot: Int) {
        var exp = Array(repeating: 0, count: 512)
        var log = Array(repeating: 0, count: 256)
        var x = 1
        for i in 0..<255 {
            exp[i] = x
            log[x] = i
            x <<= 1
            if x & 0x100 != 0 { x ^= primitive }
        }
        for i in 255..<512 { exp[i] = exp[i - 255] }
        self.exp = exp
        self.log = log
        self.firstRoot = firstRoot
    }

    func multiply(_ a: Int, _ b: Int) -> Int {
        a == 0 || b == 0 ? 0 : exp[log[a] + log[b]]
    }

    /// Generator coefficients, highest degree first, leading 1 omitted.
    func generator(degree: Int) -> [Int] {
        var poly = [1]
        for i in 0..<degree {
            let root = exp[i + firstRoot]
            var next = Array(repeating: 0, count: poly.count + 1)
            for (j, coefficient) in poly.enumerated() {
                next[j] ^= coefficient
                next[j + 1] ^= multiply(coefficient, root)
            }
            poly = next
        }
        return Array(poly.dropFirst())
    }

    func ecc(for data: [UInt8], count: Int) -> [UInt8] {
        let generator = generator(degree: count)
        var remainder = Array(repeating: 0, count: count)
        for byte in data {
            let factor = Int(byte) ^ remainder[0]
            remainder.removeFirst()
            remainder.append(0)
            for j in 0..<count { remainder[j] ^= multiply(generator[j], factor) }
        }
        return remainder.map { UInt8($0) }
    }
}
