import Foundation

// OWNER: Result module (stub). The lead implements pass signing; keep this API stable.
/// Builds a signed Apple Wallet boarding pass. Until signing exists, `isAvailable` is false
/// and the Travel result doesn't offer "Add to Apple Wallet".
enum WalletPassService {
    enum Failure: Error { case unavailable }

    static var isAvailable: Bool { false }

    static func makePass(for pass: BoardingPass, raw: String, symbology: Symbology) async throws -> Data {
        throw Failure.unavailable
    }
}
