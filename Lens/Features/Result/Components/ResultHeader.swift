import SwiftUI

/// Kind tile, "LINK · QR CODE" micro label, big title, subtitle and the close button.
struct ResultHeader: View {
    var kind: CodeKind
    var symbology: Symbology
    var title: String
    var subtitle: String
    var tint: Color? = nil
    var onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            KindTile(kind: kind, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                MicroLabel("\(String(localized: kind.title)) · \(symbology.displayName)")
                Text(title)
                    .font(.title.bold())
                    .foregroundStyle(tint ?? .primary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.opacity)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 30, height: 30)
            }
            .lensGlassButtonStyle()
            .buttonBorderShape(.circle)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Close")
        }
    }
}
