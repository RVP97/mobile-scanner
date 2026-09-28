import SwiftUI

// OWNER: Result module.
/// The result sheet: one header, a body built for what the code means, then its actions.
struct ResultView: View {
    var result: ScanResult

    @Environment(AppModel.self) private var model
    /// A better title found after the fact (a product's name from the lookup).
    @State private var resolvedTitle: String?
    /// Set when a link turns out to be dangerous, so the header reads as a warning.
    @State private var isDangerous = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ResultHeader(
                    kind: result.payload.kind,
                    symbology: result.code.symbology,
                    title: resolvedTitle ?? result.payload.displayTitle,
                    subtitle: resolvedTitle == nil ? result.payload.displaySubtitle : result.payload.displayTitle,
                    tint: isDangerous ? Palette.danger : nil,
                    onClose: model.dismissResult
                )
                .animation(.smooth, value: resolvedTitle)

                content

                if let placeName = result.placeName {
                    Label("Scanned at \(placeName)", systemImage: "mappin.and.ellipse")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder private var content: some View {
        switch result.payload {
        case .link(let url): LinkResultView(url: url, result: result, isDangerous: $isDangerous)
        case .wifi(let network): WiFiResultView(network: network, result: result)
        case .product(let gtin): ProductResultView(gtin: gtin, result: result, resolvedTitle: $resolvedTitle)
        case .contact(let card): ContactResultView(card: card, result: result)
        case .event(let event): EventResultView(event: event, result: result)
        case .email(let message): EmailResultView(message: message, result: result)
        case .sms(let message): SMSResultView(message: message, result: result)
        case .phone(let number): PhoneResultView(number: number, result: result)
        case .location(let point): LocationResultView(point: point, result: result)
        case .travel(let pass): TravelResultView(pass: pass, result: result)
        case .crypto(let request): CryptoResultView(request: request, result: result)
        case .shipment(let number): ShipmentResultView(number: number, result: result)
        case .text(let text): TextResultView(text: text, result: result)
        }
    }
}

#if DEBUG
#Preview("Link") { ResultPreview(.sampleLink) }
#Preview("Danger") { ResultPreview(.sampleDanger) }
#Preview("Wi-Fi") { ResultPreview(.sampleWiFi) }
#Preview("Product") { ResultPreview(.sampleProduct) }
#Preview("Boarding pass") { ResultPreview(.sampleTravel) }
#Preview("Contact") { ResultPreview(.sampleContact) }
#Preview("Event") { ResultPreview(.sampleEvent) }
#Preview("Location") { ResultPreview(.sampleLocation) }
#Preview("Crypto") { ResultPreview(.sampleCrypto) }
#Preview("Shipment") { ResultPreview(.sampleShipment) }
#Preview("Text") { ResultPreview(.sampleText) }
#endif
