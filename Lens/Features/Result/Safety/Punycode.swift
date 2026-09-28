import Foundation

/// RFC 3492 decoder, so `xn--pple-43d.com` can be shown and analysed as `аpple.com`.
enum Punycode {
    static func decodeHost(_ host: String) -> String {
        host.split(separator: ".", omittingEmptySubsequences: false).map { label in
            guard label.lowercased().hasPrefix("xn--") else { return String(label) }
            return decode(String(label.dropFirst(4))) ?? String(label)
        }
        .joined(separator: ".")
    }

    static func decode(_ input: String) -> String? {
        let base = 36, tMin = 1, tMax = 26
        var n = 128, i = 0, bias = 72
        var output: [Unicode.Scalar] = []
        var encoded = Substring(input)

        if let delimiter = input.lastIndex(of: "-") {
            for character in input[..<delimiter] {
                guard character.isASCII, let scalar = character.unicodeScalars.first else { return nil }
                output.append(scalar)
            }
            encoded = input[input.index(after: delimiter)...]
        }

        var digits = encoded.makeIterator()
        while let first = digits.next() {
            let oldI = i
            var weight = 1
            var k = base
            var character: Character? = first
            while true {
                guard let current = character, let digit = digitValue(current) else { return nil }
                i += digit * weight
                guard i < 0x10FFFF * 64 else { return nil }
                let threshold = k <= bias ? tMin : (k >= bias + tMax ? tMax : k - bias)
                if digit < threshold { break }
                weight *= base - threshold
                k += base
                character = digits.next()
            }
            bias = adapt(delta: i - oldI, points: output.count + 1, first: oldI == 0)
            n += i / (output.count + 1)
            i %= output.count + 1
            guard let scalar = Unicode.Scalar(n) else { return nil }
            output.insert(scalar, at: i)
            i += 1
        }
        var result = ""
        result.unicodeScalars.append(contentsOf: output)
        return result
    }

    private static func adapt(delta: Int, points: Int, first: Bool) -> Int {
        let base = 36, tMin = 1, tMax = 26, skew = 38, damp = 700
        var delta = first ? delta / damp : delta / 2
        delta += delta / points
        var k = 0
        while delta > ((base - tMin) * tMax) / 2 {
            delta /= base - tMin
            k += base
        }
        return k + (base - tMin + 1) * delta / (delta + skew)
    }

    private static func digitValue(_ character: Character) -> Int? {
        guard let ascii = character.asciiValue else { return nil }
        switch ascii {
        case UInt8(ascii: "a")...UInt8(ascii: "z"): return Int(ascii - UInt8(ascii: "a"))
        case UInt8(ascii: "A")...UInt8(ascii: "Z"): return Int(ascii - UInt8(ascii: "A"))
        case UInt8(ascii: "0")...UInt8(ascii: "9"): return Int(ascii - UInt8(ascii: "0")) + 26
        default: return nil
        }
    }
}
