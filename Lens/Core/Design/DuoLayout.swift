import SwiftUI

// iPhone Duo (iOS 27.1): the inner display can fold like a book, and nothing tappable should sit on
// the fold. Wide layouts split where the hinge is, so nothing moves as the display folds. On every
// other iPhone and iPad the split falls at the middle. On the outer display, and the inner one held
// sideways, the status bar is a column down one side where the system puts its own bars' buttons; the
// scanner's controls go there too. See docs/IPHONE_DUO.md.

extension View {
    /// Calls `action` with the edge the system lays bars down (iPhone Duo's status column), or nil
    /// where bars run across as usual (every other iPhone and iPad).
    func onStatusColumnChange(_ action: @escaping (HorizontalEdge?) -> Void) -> some View {
        modifier(StatusColumnReader(action: action))
    }

    /// For a view that fills the status bar's column: nudges it onto the line the clock and Wi-Fi
    /// stand on (the camera's center), which isn't always the column's middle.
    func alignsWithStatusColumn() -> some View { modifier(StatusColumnAxis()) }

    /// Calls `action` with the fold running down this view (folded like a book), in this view's
    /// coordinates, margins included; nil when there's none (flat, closed, or no hinge at all).
    func onVerticalFoldChange(_ action: @escaping (ClosedRange<CGFloat>?) -> Void) -> some View {
        modifier(VerticalFoldReader(action: action))
    }
}

private struct StatusColumnReader: ViewModifier {
    let action: (HorizontalEdge?) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.modifier(StatusColumnReader271(action: action))
        } else {
            content.onAppear { action(StatusColumn.override) }
        }
    }
}

@available(iOS 27.1, *)
private struct StatusColumnReader271: ViewModifier {
    let action: (HorizontalEdge?) -> Void
    @Environment(\.toolbarVerticalEdge) private var edge

    func body(content: Content) -> some View {
        content.onChange(of: StatusColumn.override ?? edge, initial: true) { _, new in action(new) }
    }
}

enum StatusColumn {
    /// Below the clock and status icons at the head of the column.
    static let clearance: CGFloat = 184

    /// Debug: `-statusColumn leading|trailing` lays out as if there were one (checking it without a Duo).
    static let override: HorizontalEdge? = {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-statusColumn"), i + 1 < args.count {
            return args[i + 1] == "trailing" ? .trailing : .leading
        }
        #endif
        return nil
    }()
}

private struct StatusColumnAxis: ViewModifier {
    @State private var nudge: CGFloat = 0

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content
                .offset(x: nudge)
                // Measured outside the nudge (an offset moves only what's drawn), so it doesn't chase
                // itself. Mid-layout the regions can read empty: the last nudge stays then.
                .onGeometryChange(for: CGFloat?.self, of: Self.nudge(in:)) { if let new = $0 { nudge = new } }
        } else {
            content
        }
    }

    /// The camera at the head of the column is the smallest occlusion region in it (the status bar's
    /// whole block is one too).
    @available(iOS 27.1, *)
    nonisolated private static func nudge(in proxy: GeometryProxy) -> CGFloat? {
        let width = proxy.size.width
        let cameras = proxy.reservedRegions(kind: .occlusion, options: [.includeInactive])
            .map(\.frame)
            .filter { $0.midX > 0 && $0.midX < width }
        guard let camera = cameras.min(by: { $0.width * $0.height < $1.width * $1.height }) else { return nil }
        return camera.midX - width / 2
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
