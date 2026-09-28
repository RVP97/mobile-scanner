import SwiftUI

/// Flat rounded surface for grouped result content. Content, not chrome: no glass.
struct ResultCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.tertiary, in: .rect(cornerRadius: 20, style: .continuous))
    }
}

/// A labelled value inside a card ("Password", "Seat").
struct DetailRow<Accessory: View>: View {
    var label: LocalizedStringKey
    var value: String
    var monospaced = false
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                MicroLabel(label)
                Text(value)
                    .font(.body)
                    .fontDesign(monospaced ? .monospaced : .default)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            accessory
        }
    }
}

extension DetailRow where Accessory == EmptyView {
    init(label: LocalizedStringKey, value: String, monospaced: Bool = false) {
        self.init(label: label, value: value, monospaced: monospaced) { EmptyView() }
    }
}

/// A hairline between rows of a card.
struct CardDivider: View {
    var body: some View {
        Divider().overlay(.separator.opacity(0.4))
    }
}

/// An icon-only accessory button inside a row (reveal, copy). 44pt hit target.
struct RowIconButton: View {
    var symbol: String
    var label: LocalizedStringKey
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(Text(label))
    }
}

extension SafetyVerdict.Level {
    var tint: Color {
        switch self {
        case .safe: Palette.safe
        case .caution: Palette.caution
        case .danger: Palette.danger
        case .unknown: .secondary
        }
    }

    var pillText: LocalizedStringKey {
        switch self {
        case .safe: "Looks safe"
        case .caution: "Be careful"
        case .danger: "Dangerous"
        case .unknown: "Not checked"
        }
    }

    var pillSymbol: String {
        switch self {
        case .safe: "checkmark.shield.fill"
        case .caution: "exclamationmark.shield.fill"
        case .danger: "xmark.shield.fill"
        case .unknown: "shield"
        }
    }
}

extension Symbology {
    /// The retail symbology a normalised GTIN is printed as.
    static func retail(forGTIN gtin: String) -> Symbology {
        switch gtin.count {
        case 8: .ean8
        case 12: .upcA
        case 14: .itf14
        default: .ean13
        }
    }
}
