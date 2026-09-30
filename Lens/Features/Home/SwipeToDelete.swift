import SwiftUI

/// Lets a row's button tell a tap from the end of a swipe (a finger lifted inside the row after a
/// horizontal drag would otherwise also open it).
final class SwipeGate {
    fileprivate var lastSwipe: TimeInterval = -.infinity

    /// True right after a swipe; a tap arriving now belongs to it.
    var isSwiping: Bool { ProcessInfo.processInfo.systemUptime - lastSwipe < 0.35 }

    fileprivate func mark() { lastSwipe = ProcessInfo.processInfo.systemUptime }
}

/// List-style swipe to delete for rows that aren't in a `List` (Home's Recent card): swipe left to
/// reveal Delete, or keep going to delete in one motion. Vertical drags are left to the scroll view.
struct SwipeToDelete: ViewModifier {
    var gate: SwipeGate?
    var onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var settledOffset: CGFloat = 0
    @State private var axis: Axis?
    @State private var width: CGFloat = 360

    private let buttonWidth: CGFloat = 84
    private var fullSwipe: CGFloat { max(width * 0.55, buttonWidth * 2) }
    private var isPastFullSwipe: Bool { -offset > fullSwipe }

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .overlay {
                // While Delete shows, a tap on the row puts it back instead of opening it.
                if settledOffset != 0 {
                    Color.clear
                        .contentShape(.rect)
                        .onTapGesture { settle(at: 0) }
                }
            }
            // On top, so it takes taps before the row or the tap-to-close layer.
            .overlay(alignment: .trailing) { deleteButton }
            .onGeometryChangeCompat { width = $0 }
            .simultaneousGesture(drag)
            .sensoryFeedback(.impact(weight: .medium), trigger: isPastFullSwipe) { _, past in past }
            .accessibilityAction(named: Text("Delete"), onDelete)
    }

    private var deleteButton: some View {
        let reveal = max(0, -offset)
        return Button(role: .destructive) {
            delete()
        } label: {
            Image(systemName: "trash.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .scaleEffect(min(1, reveal / buttonWidth))
                .frame(width: max(reveal, 0), alignment: isPastFullSwipe ? .leading : .center)
                .padding(.leading, isPastFullSwipe ? 28 : 0)
                .frame(maxHeight: .infinity)
                .background(Color.red)
                .animation(.snappy(duration: 0.2), value: isPastFullSwipe)
        }
        .buttonStyle(.plain)
        .opacity(reveal > 0 ? 1 : 0)
        .allowsHitTesting(reveal > 0)
        .accessibilityHidden(true)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let dx = value.translation.width, dy = value.translation.height
                if axis == nil { axis = abs(dx) > abs(dy) * 1.2 ? .horizontal : .vertical }
                guard axis == .horizontal else { return }
                gate?.mark()
                let proposed = settledOffset + dx
                // Rubber band past the right edge.
                offset = proposed > 0 ? proposed * 0.15 : proposed
            }
            .onEnded { value in
                defer { axis = nil }
                guard axis == .horizontal else { return }
                gate?.mark()
                let projected = settledOffset + value.predictedEndTranslation.width
                if isPastFullSwipe || projected < -fullSwipe * 1.4 {
                    delete()
                } else if projected < -buttonWidth / 2 {
                    settle(at: -buttonWidth)
                } else {
                    settle(at: 0)
                }
            }
    }

    private func settle(at target: CGFloat) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            offset = target
            settledOffset = target
        }
    }

    private func delete() {
        withAnimation(.snappy(duration: 0.22)) { offset = -width }
        Task {
            try? await Task.sleep(for: .milliseconds(160))
            onDelete()
        }
    }
}

extension View {
    func swipeToDelete(gate: SwipeGate? = nil, perform onDelete: @escaping () -> Void) -> some View {
        modifier(SwipeToDelete(gate: gate, onDelete: onDelete))
    }

    /// The view's width as it changes (iOS 17-friendly).
    fileprivate func onGeometryChangeCompat(_ action: @escaping (CGFloat) -> Void) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { action(proxy.size.width) }
                    .onChange(of: proxy.size.width) { _, width in action(width) }
            }
        }
    }
}
