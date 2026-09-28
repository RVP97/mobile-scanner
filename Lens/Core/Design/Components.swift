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

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Palette.onTint)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(tint, in: .capsule)
            .contentShape(.capsule)
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

/// Neutral filled tile for the secondary row (Copy · Share · Show Code). Icons sit in a fixed-height
/// slot so every title in a row shares one baseline, whatever the glyph's shape.
struct SecondaryActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.primary)
            .labelStyle(StackedLabelStyle())
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(.fill.secondary, in: .rect(cornerRadius: 16, style: .continuous))
            .contentShape(.rect(cornerRadius: 16, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

/// Icon above title, used by the secondary action row.
struct StackedLabelStyle: LabelStyle {
    @ScaledMetric(relativeTo: .body) private var iconSlot: CGFloat = 22
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeBody(configuration: Configuration) -> some View {
        // At accessibility sizes the row becomes a column, so the icon moves beside its title.
        if dynamicTypeSize.isAccessibilitySize {
            HStack(spacing: 12) {
                configuration.icon.font(.body.weight(.semibold))
                configuration.title
            }
        } else {
            VStack(spacing: 6) {
                configuration.icon
                    .font(.body.weight(.semibold))
                    .frame(height: iconSlot)
                configuration.title
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

/// The sheet's close control: a quiet filled circle with a 44pt hit target. Flat on purpose,
/// so it never floats a glass halo over content.
struct SheetCloseButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.subheadline.weight(.bold))
                .imageScale(.small)
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(.fill.tertiary, in: .circle)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityLabel("Close")
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
