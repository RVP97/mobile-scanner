import SwiftUI

// Liquid Glass on iOS 26+, native materials on iOS 17–25. Feature code uses only these
// wrappers so there is exactly one place that knows about the fallback.

enum LensGlassVariant {
    case regular
    /// More transparent; for controls floating over the camera or photos.
    case clear
}

extension View {
    /// Glass surface for floating chrome. Never use on content.
    @ViewBuilder
    func lensGlass<S: Shape>(
        _ variant: LensGlassVariant = .regular,
        in shape: S,
        interactive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        if #available(iOS 26.0, *) {
            let base: Glass = variant == .clear ? .clear : .regular
            let tinted = tint.map { base.tint($0) } ?? base
            self.glassEffect(tinted.interactive(interactive), in: shape)
        } else {
            self
                .background(variant == .clear ? .ultraThinMaterial : .regularMaterial, in: shape)
                .background(tint?.opacity(0.35) ?? .clear, in: shape)
                .overlay(shape.stroke(.white.opacity(0.18), lineWidth: 0.5))
        }
    }

    /// Identifies a glass element so it morphs between states inside a `LensGlassContainer`.
    @ViewBuilder
    func lensGlassID<ID: Hashable & Sendable>(_ id: ID, in namespace: Namespace.ID) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self
        }
    }

    /// `.glass` / `.glassProminent` on iOS 26, bordered styles before.
    ///
    /// A prominent button draws a white label by default. On a light tint (the dark-mode accent)
    /// that fails contrast, so give the label `.foregroundStyle(Palette.onTint)`.
    @ViewBuilder
    func lensGlassButtonStyle(prominent: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            if prominent {
                self.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
            } else {
                self.buttonStyle(.bordered).buttonBorderShape(.capsule)
            }
        }
    }
}

/// Groups nearby glass elements so they blend and morph (iOS 26); a plain container before.
struct LensGlassContainer<Content: View>: View {
    var spacing: CGFloat?
    @ViewBuilder var content: Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
