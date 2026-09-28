import SwiftUI

/// The top of every result. Two shapes:
/// - **Hero**: kind tile, "LINK · QR CODE", the one line that names the code, an optional subtitle.
/// - **Compact**: a slim label row, for results whose body is the hero (a boarding pass, a note).
/// The body below never repeats what the header says.
struct ResultHeader: View {
    var kind: CodeKind
    var symbology: Symbology
    var heading: ResultHeading
    var tint: Color? = nil
    var onClose: () -> Void

    var body: some View {
        if let title = heading.title {
            hero(title: title)
        } else {
            compact
        }
    }

    private func hero(title: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            if let monogram = heading.monogram {
                Text(monogram)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(kind.tint)
                    .frame(width: 52, height: 52)
                    .background(Palette.tileFill(kind), in: .circle)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .accessibilityHidden(true)
            } else {
                KindTile(kind: kind, size: 52)
            }
            VStack(alignment: .leading, spacing: 4) {
                MicroLabel("\(String(localized: kind.title)) · \(symbology.displayName)")
                Text(title)
                    .font(.title2.bold())
                    .fontDesign(heading.monospacedTitle ? .monospaced : .default)
                    .monospacedDigit()
                    .foregroundStyle(tint ?? .primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .contentTransition(.opacity)
                if let subtitle = heading.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.top, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            SheetCloseButton(action: onClose)
                .padding(.top, -6)
                .padding(.trailing, -8)
        }
    }

    private var compact: some View {
        HStack(spacing: 12) {
            KindTile(kind: kind, size: 36)
            VStack(alignment: .leading, spacing: 0) {
                Text(kind.title)
                    .font(.headline)
                Text(symbology.displayName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            SheetCloseButton(action: onClose)
                .padding(.trailing, -8)
        }
    }
}
