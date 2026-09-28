import Foundation

/// Builds a signed Apple Wallet boarding pass through Lens's signing service
/// (`bloom.vallepinto.com/lens`). Wallet only accepts signed passes, and the signing key
/// can't ship inside the app, so this is the one feature that talks to a Lens server.
enum WalletPassService {
    /// Flip on once the signing Worker is deployed. The Worker also has its own kill switch.
    static let isServiceLive = false

    static var isAvailable: Bool { isServiceLive && AddPassSheet.isAvailable }

    static func makePass(for pass: BoardingPass, raw: String, symbology: Symbology) async throws -> Data {
        try await WalletClient.shared.makeBoardingPass(pass, raw: raw, symbology: symbology)
    }
}
