import SwiftUI

/// Pages pushed inside the Settings modal.
enum SettingsRoute: Hashable {
    case scanAnywhere
    case privacy
}

/// A settings row title with the system-style filled glyph tile in front of it.
struct SettingsLabel: View {
    var title: Text
    var symbol: String
    var color: Color
    var subtitle: Text?

    init(_ title: LocalizedStringKey, symbol: String, color: Color, subtitle: LocalizedStringKey? = nil) {
        self.title = Text(title)
        self.symbol = symbol
        self.color = color
        self.subtitle = subtitle.map { Text($0) }
    }

    init(_ title: LocalizedStringResource, symbol: String, color: Color) {
        self.title = Text(title)
        self.symbol = symbol
        self.color = color
    }

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                title
                if let subtitle {
                    subtitle
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            SettingsGlyph(symbol: symbol, color: color)
        }
    }
}

/// White glyph on a small filled continuous square, like the Settings app.
struct SettingsGlyph: View {
    var symbol: String
    var color: Color
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 29

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: side * 0.52, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: side, height: side)
            .background(color, in: .rect(cornerRadius: side * 0.26, style: .continuous))
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    Form {
        SettingsLabel("Haptics", symbol: "waveform", color: .pink)
        SettingsLabel("Remember where I scanned", symbol: "location.fill", color: .blue,
                      subtitle: "Place names only, kept on this iPhone")
    }
}
#endif
