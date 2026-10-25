import SwiftUI

// A code card on Home grows into the full-screen code, and shrinks back into its card when the code
// is put away (a swipe down follows the finger). iOS 18 and later; before that the code slides up.

extension EnvironmentValues {
    /// Where Home's cards and the full-screen code meet, set by the root.
    @Entry var codeZoomNamespace: Namespace.ID?
}

extension View {
    /// Marks a card as where the full-screen code with this `id` opens from and closes into.
    func codeZoomSource(id: UUID) -> some View {
        modifier(CodeZoomSource(id: id))
    }

    /// The full-screen code: zooms out of the card with `id`, when it was opened from one.
    func codeZoomDestination(id: UUID?, in namespace: Namespace.ID) -> some View {
        modifier(CodeZoomDestination(id: id, namespace: namespace))
    }
}

private struct CodeZoomSource: ViewModifier {
    let id: UUID
    @Environment(\.codeZoomNamespace) private var namespace

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), let namespace {
            content.matchedTransitionSource(id: id, in: namespace) { source in
                source.clipShape(.rect(cornerRadius: CodeCard.cornerRadius, style: .continuous))
            }
        } else {
            content
        }
    }
}

private struct CodeZoomDestination: ViewModifier {
    let id: UUID?
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), let id {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}
