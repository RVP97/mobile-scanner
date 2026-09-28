import SwiftUI

/// Draws an `ArtworkScene` as vectors, aspect-fit. Crisp at any size, cheap to repaint.
struct CodeCanvas: View {
    var scene: ArtworkScene?

    var body: some View {
        Canvas { context, size in
            guard let scene else { return }
            context.withCGContext { SceneRenderer.draw(scene, in: $0, rect: CGRect(origin: .zero, size: size)) }
        }
    }
}

/// A selectable option drawn from a path (dot shapes, eye shapes, frame styles).
struct ShapeSwatch<Glyph: View>: View {
    var title: LocalizedStringResource
    var isSelected: Bool
    var action: () -> Void
    @ViewBuilder var glyph: Glyph

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                glyph
                    .foregroundStyle(.primary)
                    .padding(10)
                    .frame(width: 52, height: 52)
                    .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(isSelected ? Palette.accent : .clear, lineWidth: 2.5)
                    }
                Text(title)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            .frame(minWidth: 56)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Fills a module-unit `CGPath` scaled to fit the view.
struct PathGlyph: View {
    var path: CGPath
    var evenOdd = false

    var body: some View {
        GeometryReader { proxy in
            let box = path.boundingBoxOfPath
            let scale = min(proxy.size.width / max(box.width, 0.001), proxy.size.height / max(box.height, 0.001))
            let transform = CGAffineTransform(translationX: -box.minX, y: -box.minY)
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(
                    translationX: (proxy.size.width - box.width * scale) / 2,
                    y: (proxy.size.height - box.height * scale) / 2
                ))
            Path(path).applying(transform).fill(style: FillStyle(eoFill: evenOdd))
        }
    }
}

/// A style rendered onto a fixed sample code, for presets and My styles.
struct StyleThumbnail: View {
    var style: CodeStyle
    var logoImage: CGImage?

    /// Same payload for every thumbnail so only the look differs.
    private static let sample = CoreImageEncoder.qr("https://lens.app/styles", correction: .high)

    var body: some View {
        CodeCanvas(scene: scene)
            .frame(width: 60, height: 60)
            .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 14, style: .continuous))
            .accessibilityHidden(true)
    }

    private var scene: ArtworkScene? {
        guard let matrix = Self.sample else { return nil }
        var look = style
        look.frame = .none
        let logo: CGImage? = switch look.logo {
        case .photo(let data, _): LogoImages.decode(data)
        case .kindGlyph: logoImage
        default: nil
        }
        return SceneBuilder.scene(for: SceneInput(
            graphic: .matrix(matrix, quietZone: 2), geometry: .qr(matrix, style: look), style: look, logoImage: logo
        ))
    }
}
