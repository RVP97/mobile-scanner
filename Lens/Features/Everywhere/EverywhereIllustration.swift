import SwiftUI

/// A tiny, schematic crop of where the shortcut lives, with Lens highlighted.
struct EverywhereIllustration: View {
    var shortcut: EverywhereShortcut
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(Color(white: 0.1))
            content
        }
        .frame(width: size, height: size)
        .environment(\.colorScheme, .dark)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        let unit = size / 64
        switch shortcut {
        case .controlCenter:
            // A slice of the Control Center grid; the Scan control lit up.
            Grid(horizontalSpacing: 5 * unit, verticalSpacing: 5 * unit) {
                GridRow {
                    tile(unit)
                    tile(unit, highlighted: true)
                }
                GridRow {
                    tile(unit)
                    tile(unit)
                }
            }
        case .actionButton:
            // The phone's left edge with the Action button pressed.
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10 * unit, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1.5 * unit)
                    .frame(width: 34 * unit, height: 50 * unit)
                    .offset(x: 18 * unit)
                Capsule()
                    .fill(Palette.accent)
                    .frame(width: 4 * unit, height: 12 * unit)
                    .offset(x: 13 * unit, y: -12 * unit)
                LunetGlyph()
                    .foregroundStyle(Palette.accent)
                    .frame(width: 18 * unit, height: 18 * unit)
                    .offset(x: 26 * unit, y: -12 * unit)
            }
            .frame(width: size, height: size, alignment: .leading)
        case .lockScreen:
            // Time at the top, the two bottom buttons; Lunet in the left one.
            VStack(spacing: 0) {
                Text(verbatim: "9:41")
                    .font(.system(size: 15 * unit, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 8 * unit)
                Spacer()
                HStack {
                    Circle()
                        .fill(Palette.accent.opacity(0.28))
                        .overlay {
                            LunetGlyph()
                                .foregroundStyle(Palette.accent)
                                .padding(3 * unit)
                        }
                    Spacer()
                    Circle().fill(.white.opacity(0.18))
                }
                .frame(height: 18 * unit)
                .padding(.horizontal, 8 * unit)
                .padding(.bottom, 8 * unit)
            }
        }
    }

    private func tile(_ unit: CGFloat, highlighted: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 7 * unit, style: .continuous)
            .fill(highlighted ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(.white.opacity(0.16)))
            .frame(width: 20 * unit, height: 20 * unit)
            .overlay {
                if highlighted {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 11 * unit, weight: .semibold))
                        .foregroundStyle(.black)
                }
            }
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach(EverywhereShortcut.allCases) { EverywhereIllustration(shortcut: $0) }
    }
    .padding()
}
