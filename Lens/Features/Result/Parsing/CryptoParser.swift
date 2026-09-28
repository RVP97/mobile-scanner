import CryptoKit
import Foundation

/// Payment URIs (`bitcoin:`, `ethereum:`, `litecoin:`, `lightning:`) and bare addresses whose checksum verifies.
enum CryptoParser {
    static let schemes = ["bitcoin", "ethereum", "litecoin", "lightning", "bitcoincash", "dogecoin", "monero", "solana"]

    static func parseURI(_ raw: String) -> CryptoRequest? {
        guard let colon = raw.firstIndex(of: ":") else { return nil }
        let scheme = raw[..<colon].lowercased()
        guard schemes.contains(scheme) else { return nil }

        var rest = raw[raw.index(after: colon)...]
        if rest.hasPrefix("//") { rest = rest.dropFirst(2) }
        let question = rest.firstIndex(of: "?")
        var address = String(rest[..<(question ?? rest.endIndex)]).percentDecoded.trimmed
        // EIP-681: `ethereum:pay-0xABC@1/transfer?...`
        if address.hasPrefixIgnoringCase("pay-") { address = String(address.dropFirst(4)) }
        if scheme == "ethereum", let cut = address.firstIndex(where: { $0 == "@" || $0 == "/" }) {
            address = String(address[..<cut])
        }
        guard !address.isEmpty else { return nil }

        var request = CryptoRequest(scheme: scheme, address: address)
        if let question {
            let query = QueryString.parameters(rest[rest.index(after: question)...])
            request.amount = query["amount"] ?? query["value"] ?? ""
            request.label = query["label"] ?? query["message"] ?? ""
        }
        return request
    }

    /// A bare Bitcoin (base58check or bech32), Ethereum or Lightning string.
    static func parseBareAddress(_ raw: String) -> CryptoRequest? {
        if raw.wholeMatch(of: /0x[0-9a-fA-F]{40}/) != nil {
            return CryptoRequest(scheme: "ethereum", address: raw)
        }
        let lower = raw.lowercased()
        if lower.hasPrefix("lnbc") || lower.hasPrefix("lnurl"), raw.count > 20,
           raw.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) {
            return CryptoRequest(scheme: "lightning", address: raw)
        }
        if (lower.hasPrefix("bc1") || lower.hasPrefix("ltc1")), Bech32.isValid(raw) {
            return CryptoRequest(scheme: lower.hasPrefix("bc1") ? "bitcoin" : "litecoin", address: raw)
        }
        if (26...35).contains(raw.count), let payload = Base58.decodeChecked(raw), payload.count == 21 {
            switch payload[0] {
            case 0x00, 0x05: return CryptoRequest(scheme: "bitcoin", address: raw)
            case 0x30, 0x32: return CryptoRequest(scheme: "litecoin", address: raw)
            default: return nil
            }
        }
        return nil
    }
}

extension CryptoRequest {
    /// "Bitcoin", "Ethereum"…
    var networkName: String {
        switch scheme.lowercased() {
        case "bitcoin": "Bitcoin"
        case "ethereum": "Ethereum"
        case "litecoin": "Litecoin"
        case "lightning": "Lightning"
        case "bitcoincash": "Bitcoin Cash"
        case "dogecoin": "Dogecoin"
        case "monero": "Monero"
        case "solana": "Solana"
        default: scheme.capitalized
        }
    }

    var currencyCode: String {
        switch scheme.lowercased() {
        case "bitcoin", "lightning": "BTC"
        case "ethereum": "ETH"
        case "litecoin": "LTC"
        case "bitcoincash": "BCH"
        case "dogecoin": "DOGE"
        case "monero": "XMR"
        case "solana": "SOL"
        default: scheme.uppercased()
        }
    }

    /// "bc1qar0s…zzwf5mdq" for tight spaces.
    var shortAddress: String {
        guard address.count > 18 else { return address }
        return "\(address.prefix(8))…\(address.suffix(8))"
    }
}

enum Base58 {
    private static let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
    private static let indexes: [Character: Int] = Dictionary(
        uniqueKeysWithValues: alphabet.enumerated().map { ($1, $0) }
    )

    /// Decodes and verifies the 4-byte double-SHA256 checksum. Returns the payload without it.
    static func decodeChecked(_ text: String) -> [UInt8]? {
        var bytes: [UInt8] = []
        for character in text {
            guard var carry = indexes[character] else { return nil }
            for index in bytes.indices.reversed() {
                carry += Int(bytes[index]) * 58
                bytes[index] = UInt8(carry & 0xFF)
                carry >>= 8
            }
            while carry > 0 {
                bytes.insert(UInt8(carry & 0xFF), at: 0)
                carry >>= 8
            }
        }
        let zeros = text.prefix { $0 == "1" }.count
        bytes = Array(repeating: 0, count: zeros) + bytes
        guard bytes.count > 4 else { return nil }
        let payload = Array(bytes.dropLast(4))
        let checksum = Array(SHA256.hash(data: Data(SHA256.hash(data: Data(payload))))).prefix(4)
        return Array(checksum) == Array(bytes.suffix(4)) ? payload : nil
    }
}

/// BIP-173 / BIP-350 checksum verification (bech32 and bech32m).
enum Bech32 {
    private static let charset = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l")

    static func isValid(_ text: String) -> Bool {
        guard (14...90).contains(text.count), text == text.lowercased() || text == text.uppercased() else { return false }
        let lower = text.lowercased()
        guard let separator = lower.lastIndex(of: "1") else { return false }
        let hrp = lower[..<separator]
        let data = lower[lower.index(after: separator)...]
        guard !hrp.isEmpty, data.count >= 6 else { return false }
        var values: [UInt32] = []
        for character in data {
            guard let value = charset.firstIndex(of: character) else { return false }
            values.append(UInt32(value))
        }
        let expanded = hrp.unicodeScalars.map { $0.value >> 5 } + [0] + hrp.unicodeScalars.map { $0.value & 31 }
        let check = polymod(expanded + values)
        return check == 1 || check == 0x2BC8_30A3
    }

    private static func polymod(_ values: [UInt32]) -> UInt32 {
        let generator: [UInt32] = [0x3B6A_57B2, 0x2650_8E6D, 0x1EA1_19FA, 0x3D42_33DD, 0x2A14_62B3]
        var checksum: UInt32 = 1
        for value in values {
            let top = checksum >> 25
            checksum = (checksum & 0x1FF_FFFF) << 5 ^ value
            for index in 0..<5 where (top >> UInt32(index)) & 1 == 1 {
                checksum ^= generator[index]
            }
        }
        return checksum
    }
}
