import PassKit
import SwiftUI

/// Apple's "Add to Apple Wallet" badge for a boarding pass, with the signing round trip and its
/// failure message. Shows nothing where Wallet passes can't be made (the Simulator, some iPads).
struct WalletPassButton: View {
    var pass: BoardingPass
    var raw: String
    var symbology: Symbology
    /// The privacy note under the badge.
    var showsFootnote = true

    @Environment(\.colorScheme) private var colorScheme
    @State private var walletPass: PKPass?
    @State private var walletError: String?
    @State private var isPreparing = false

    static var isAvailable: Bool { WalletPassService.isAvailable && PKAddPassesViewController.canAddPasses() }

    var body: some View {
        if Self.isAvailable {
            VStack(alignment: .leading, spacing: 8) {
                // Apple's own badge, as Wallet's branding guidelines require.
                AddPassButton(style: colorScheme == .dark ? .blackOutline : .black) {
                    guard !isPreparing else { return }
                    Task { await prepare() }
                }
                .frame(height: 54)
                .opacity(isPreparing ? 0.5 : 1)
                .overlay { if isPreparing { ProgressView().tint(.white) } }
                .accessibilityLabel("Add to Apple Wallet")
                if showsFootnote {
                    Text("Pass details are sent to Lunet's signing service to create your pass. Nothing is stored.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let walletError {
                    Label(walletError, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Palette.caution)
                }
            }
            .sheet(isPresented: Binding(get: { walletPass != nil }, set: { if !$0 { walletPass = nil } })) {
                if let walletPass { AddPassSheet(pass: walletPass).ignoresSafeArea() }
            }
        }
    }

    private func prepare() async {
        isPreparing = true
        defer { isPreparing = false }
        do {
            let data = try await WalletPassService.makePass(for: pass, raw: raw, symbology: symbology)
            walletPass = try PKPass(data: data)
            walletError = nil
        } catch {
            walletError = String(localized: "Couldn't create a Wallet pass for this flight.")
        }
    }
}
