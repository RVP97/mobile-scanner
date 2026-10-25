import SwiftUI

// Lunet's haptics, all behind Settings › Haptics. Each one means one thing everywhere:
// - `.selection`: a choice changed (a filter, a tool, pinned or not, Multi-scan on or off).
// - `.success`: something the person asked for is done (copied, saved, joined, exported).
// - `.warning`: Lunet is holding something back (a flagged link, a code that may not scan).
// - `.error`: what they asked for failed.
// - impacts: physical moments (a card swiped past the point of no return, a code locking on).
// The scanner's opening and closing are `LensHaptics`, which reads the same setting.

extension View {
    /// `sensoryFeedback(_:trigger:)`, off when the person turned haptics off.
    func lensFeedback<T: Equatable>(_ feedback: SensoryFeedback, trigger: T) -> some View {
        modifier(GatedFeedback(trigger: trigger) { _, _ in feedback })
    }

    /// `sensoryFeedback(_:trigger:condition:)`, off when the person turned haptics off.
    func lensFeedback<T: Equatable>(
        _ feedback: SensoryFeedback,
        trigger: T,
        condition: @escaping (T, T) -> Bool
    ) -> some View {
        modifier(GatedFeedback(trigger: trigger) { old, new in condition(old, new) ? feedback : nil })
    }

    /// `sensoryFeedback(trigger:_:)`, off when the person turned haptics off.
    func lensFeedback<T: Equatable>(trigger: T, _ feedback: @escaping (T, T) -> SensoryFeedback?) -> some View {
        modifier(GatedFeedback(trigger: trigger, feedback: feedback))
    }
}

private struct GatedFeedback<T: Equatable>: ViewModifier {
    let trigger: T
    let feedback: (T, T) -> SensoryFeedback?
    @AppStorage(Pref.haptics) private var haptics = Pref.Default.haptics

    func body(content: Content) -> some View {
        content.sensoryFeedback(trigger: trigger) { old, new in
            haptics ? feedback(old, new) : nil
        }
    }
}
