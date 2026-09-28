import SwiftUI

/// The rounded glyph tile that identifies a code's kind everywhere in the app.
struct KindTile: View {
    var kind: CodeKind
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: kind.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(kind.tint)
            .frame(width: size, height: size)
            .background(Palette.tileFill(kind), in: .rect(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Full-width filled action in the kind's tint ("Join Network", "Open atlas-coffee.co").
struct PrimaryActionStyle: ButtonStyle {
    var tint: Color = Palette.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Palette.onTint)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(tint, in: .capsule)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

/// Neutral filled action for the secondary row (Copy · Share · Show code).
struct SecondaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .labelStyle(StackedLabelStyle())
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(.fill.secondary, in: .rect(cornerRadius: 20, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Icon above title, used by the secondary action row.
struct StackedLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 6) {
            configuration.icon.font(.system(size: 18, weight: .semibold))
            configuration.title
        }
    }
}

extension ButtonStyle where Self == PrimaryActionStyle {
    static func primaryAction(_ tint: Color = Palette.accent) -> PrimaryActionStyle { PrimaryActionStyle(tint: tint) }
}

extension ButtonStyle where Self == SecondaryActionStyle {
    static var secondaryAction: SecondaryActionStyle { SecondaryActionStyle() }
}

/// Small rounded status capsule ("Looks safe", "Check digit valid").
struct StatusPill: View {
    var text: LocalizedStringKey
    var symbol: String
    var tint: Color

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(tint.opacity(0.16), in: .capsule)
    }
}

/// Uppercase micro label used above grouped values.
struct MicroLabel: View {
    var text: LocalizedStringKey
    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.4)
            .foregroundStyle(.secondary)
    }
}
