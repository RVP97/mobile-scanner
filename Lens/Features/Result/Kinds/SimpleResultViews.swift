import SwiftUI

/// Crypto payment request: the full address in mono, amount, and a clear caution.
struct CryptoResultView: View {
    var request: CryptoRequest
    var result: ScanResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ResultCard {
                DetailRow(label: "\(request.networkName) address", value: request.address, monospaced: true)
                if !request.amount.isEmpty {
                    CardDivider()
                    DetailRow(label: "Amount", value: "\(request.amount) \(request.currencyCode)", monospaced: true)
                }
                if !request.label.isEmpty {
                    CardDivider()
                    DetailRow(label: "Label", value: request.label)
                }
                StatusPill(text: "Lens can't verify who receives this", symbol: "exclamationmark.shield.fill", tint: Palette.caution)
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

        VStack(alignment: .leading, spacing: 16) {
            ResultCard {
                DetailRow(label: "Carrier", value: carrier?.name ?? String(localized: "Unknown carrier"))
                CardDivider()
                DetailRow(label: "Tracking number", value: number, monospaced: true)
            }
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
            ResultCard {
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
