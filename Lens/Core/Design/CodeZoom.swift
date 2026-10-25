import SwiftUI

// Home's code cards grow into the full-screen code, and the Scan lens grows into the camera; each
// shrinks back into where it came from when it's put away (a swipe down follows the finger). iOS 18
// and later, where the system draws the zoom; before that they slide up.

extension EnvironmentValues {
    /// Where Home's cards and lens meet what they open, set by the root.
    @Entry var codeZoomNamespace: Namespace.ID?
}

/// The Scan lens's id in the zoom namespace.
enum ScannerZoom: Hashable {
    case lens
}

extension View {
    /// Marks this view as where the presentation with this `id` opens from and closes into, drawn
    /// with corners of `cornerRadius` (half its side for a circle) as it goes.
    func codeZoomSource(id: some Hashable, cornerRadius: CGFloat = CodeCard.cornerRadius) -> some View {
        modifier(CodeZoomSource(id: AnyHashable(id), cornerRadius: cornerRadius))
    }

    /// A presentation that zooms out of the view marked with `id`, when there is one.
    func codeZoomDestination(id: (some Hashable)?, in namespace: Namespace.ID) -> some View {
        modifier(CodeZoomDestination(id: id.map(AnyHashable.init), namespace: namespace))
    }
}

private struct CodeZoomSource: ViewModifier {
    let id: AnyHashable
    let cornerRadius: CGFloat
    @Environment(\.codeZoomNamespace) private var namespace

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), let namespace {
            content.matchedTransitionSource(id: id, in: namespace) { source in
                source.clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
            }
        } else {
            content
        }
    }
}

private struct CodeZoomDestination: ViewModifier {
    let id: AnyHashable?
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), let id {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}
