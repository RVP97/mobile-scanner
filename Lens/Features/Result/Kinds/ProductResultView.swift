import SwiftUI

/// Retail barcode: the bars themselves, check digit, GS1 prefix, and what the open databases know.
struct ProductResultView: View {
    var gtin: String
    var result: ScanResult
    /// Set to the product's name when the lookup finds it; the header shows it.
    @Binding var productName: String?

    @Environment(\.openURL) private var openURL
    @State private var outcome: ProductLookup.Outcome?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            lookupCard
            barcodeCard

            ResultPrimaryButton(title: "Search the Web", symbol: "magnifyingglass", tint: CodeKind.product.tint) {
                if let url = WebSearch.url(for: searchQuery) { openURL(url) }
            }

            ResultActionRow(result: result, copyText: gtin, showsCode: false) {
                Button {
                    if let url = WebSearch.shoppingURL(for: searchQuery) { openURL(url) }
                } label: {
                    Label("Compare Prices", systemImage: "tag")
                }
            }
        }
        .animation(.smooth, value: outcome)
        .task(id: gtin) {
            let found = await ProductLookup.lookup(gtin: gtin)
            outcome = found
            if case .found(let info) = found { productName = info.name }
        }
    }

    private var searchQuery: String {
        if case .found(let info) = outcome { return [info.brand, info.name].filter { !$0.isEmpty }.joined(separator: " ") }
        return gtin
    }

    // MARK: Lookup

    @ViewBuilder private var lookupCard: some View {
        ResultCard {
            switch outcome {
            case nil:
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Looking up this product…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            case .found(let info):
                ProductSummary(info: info)
            case .notFound:
                emptyState("No match in the open product databases",
                           detail: "Search the web to find out what this is.")
            case .unavailable:
                emptyState("Couldn't reach the product databases",
                           detail: "Check your connection, or search the web.")
            }
        }
    }

    private func emptyState(_ title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Barcode

    private var barcodeCard: some View {
        ResultCard {
            VStack(spacing: 8) {
                if let image = CodeRenderer.image(raw: gtin, symbology: .retail(forGTIN: gtin), dimension: 240) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 240, maxHeight: 110)
                        .padding(12)
                        .background(.white, in: .rect(cornerRadius: 12, style: .continuous))
                        .accessibilityHidden(true)
                }
                // The header shows the digits until the product's name replaces them.
                if productName != nil {
                    Text(GTIN.grouped(gtin))
                        .font(.body.weight(.medium))
                        .fontDesign(.monospaced)
                        .textSelection(.enabled)
                }
                checkDigitPill
            }
            .frame(maxWidth: .infinity)

            CardDivider()
            DetailRow(label: "Format", value: formatText)
            if let region = GTIN.prefixRegion(gtin) {
                CardDivider()
                DetailRow(label: "GS1 prefix", value: region)
            }
        }
    }

    @ViewBuilder private var checkDigitPill: some View {
        if GTIN.hasValidCheckDigit(gtin) {
            StatusPill(text: "Check digit valid", symbol: "checkmark.seal.fill", tint: Palette.safe)
        } else {
            StatusPill(text: "Check digit doesn't match", symbol: "exclamationmark.triangle.fill", tint: Palette.caution)
        }
    }

    private var formatText: String {
        String(localized: "\(GTIN.formatName(gtin)) · \(gtin.count) digits")
    }
}

private struct ProductSummary: View {
    var info: ProductInfo

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            AsyncImage(url: info.imageURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Image(systemName: "shippingbox")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 72, height: 72)
            .background(.white, in: .rect(cornerRadius: 12, style: .continuous))
            .clipShape(.rect(cornerRadius: 12, style: .continuous))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                // The name is the header's title; the card adds what's known about it.
                if !info.brand.isEmpty {
                    Text(info.brand).font(.headline)
                }
                let details = ([info.quantity] + info.categories).filter { !$0.isEmpty }
                if !details.isEmpty {
                    Text(details.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("Source: \(info.source)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview { ResultPreview(.sampleProduct) }
#endif
