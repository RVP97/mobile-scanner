import SwiftUI

/// Crypto payment request: the full address in mono, amount, and a clear caution.
struct CryptoResultView: View {
    var request: CryptoRequest
    var result: ScanResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Amount and payee are the header; the card is the one thing to check character by character.
            ResultCard {
                DetailRow(label: "\(request.networkName) address", value: request.address, monospaced: true)
                CardDivider()
                Label("Lunet can't verify who receives this. Check the address with the person you're paying.",
                      systemImage: "exclamationmark.shield.fill")
                    .font(.footnote)
                    .foregroundStyle(Palette.caution)
            }

            CopyButton(text: request.address, title: "Copy Address")
                .buttonStyle(.primaryAction(CodeKind.crypto.tint))

            ResultActionRow(result: result, copyText: nil)
        }
    }
}

/// Parcel tracking number: carrier, number, "Track Package".
struct ShipmentResultView: View {
    var number: String
    var result: ScanResult
    @Environment(\.openURL) private var openURL

    var body: some View {
        let carrier = ShipmentCarrier.carrier(forTrackingNumber: number)

        // Number and carrier are the header; the body is the one thing to do with them.
        VStack(alignment: .leading, spacing: 16) {
            ResultPrimaryButton(title: "Track Package", symbol: "shippingbox.fill", tint: CodeKind.shipment.tint) {
                if let url = carrier?.trackingURL(for: number) ?? WebSearch.url(for: "track \(number)") { openURL(url) }
            }
            ResultActionRow(result: result, copyText: number)
        }
    }
}

/// Plain text: selectable, searchable, copyable.
struct TextResultView: View {
    var text: String
    var result: ScanResult
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // The text is the hero: short notes read large, long ones as body copy.
            ResultCard(padding: 20) {
                Text(text)
                    .font(text.count <= 120 ? .title3.weight(.medium) : .body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("^[\(text.count) character](inflect: true)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ResultPrimaryButton(title: "Search the Web", symbol: "magnifyingglass", tint: CodeKind.text.tint) {
                if let url = WebSearch.url(for: String(text.prefix(200))) { openURL(url) }
            }
            ResultActionRow(result: result, copyText: text)
        }
    }
}

#if DEBUG
#Preview("Crypto") { ResultPreview(.sampleCrypto) }
#Preview("Shipment") { ResultPreview(.sampleShipment) }
#Preview("Text") { ResultPreview(.sampleText) }
#endif
