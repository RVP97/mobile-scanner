import SwiftUI

// iPhone Duo (iOS 27.1): the inner display can fold like a book, and nothing tappable should sit on
// the fold. Wide layouts split where the hinge is, so nothing moves as the display folds. On every
// other iPhone and iPad the split falls at the middle. See docs/IPHONE_DUO.md.

extension View {
    /// Calls `action` with the fold running down this view (folded like a book), in this view's
    /// coordinates, margins included; nil when there's none (flat, closed, or no hinge at all).
    func onVerticalFoldChange(_ action: @escaping (ClosedRange<CGFloat>?) -> Void) -> some View {
        modifier(VerticalFoldReader(action: action))
    }
}

private struct VerticalFoldReader: ViewModifier {
    let action: (ClosedRange<CGFloat>?) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onGeometryChange(for: ClosedRange<CGFloat>?.self, of: Self.fold(in:), action: action)
        } else {
            content
        }
    }

    @available(iOS 27.1, *)
    nonisolated private static func fold(in proxy: GeometryProxy) -> ClosedRange<CGFloat>? {
        let size = proxy.size
        // Active divisions only: a flat display has none.
        for region in proxy.reservedRegions(kind: .division) where region.isActive {
            let frame = region.frame
            if frame.height >= frame.width, frame.minX > 0, frame.maxX < size.width {
                return frame.minX...frame.maxX
            }
        }
        return nil
    }
}

/// Two panes side by side, split at the hinge: at the fold (and its margins) folded like a book, at the
/// display's middle when flat. The split is worked out from the width given as it's laid out, never
/// from one measured earlier, so turning the device can't leave a pane sized for the old screen.
struct HingeSplit<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    @State private var fold: ClosedRange<CGFloat>?

    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            // The middle of the whole display, the status bar's column included.
            let hinge = ((proxy.size.width + insets.leading + insets.trailing) / 2 - insets.leading).rounded()
            let split = fold ?? hinge...hinge
            HStack(spacing: 0) {
                leading
                    .frame(width: max(split.lowerBound, 0))
                Color.clear
                    .frame(width: split.upperBound - split.lowerBound)
                    .accessibilityHidden(true)
                trailing
                    .frame(maxWidth: .infinity)
            }
        }
        .onVerticalFoldChange { new in withAnimation(.smooth(duration: 0.35)) { fold = new } }
    }
}
