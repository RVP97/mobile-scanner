import SwiftUI

/// Content with actions pinned to the bottom. Content scrolls only when it has to (small phones,
/// accessibility text sizes); hero pages center it in the space above the actions when it fits.
struct OnboardingPage<Content: View, Actions: View>: View {
    var centered = false
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ViewThatFits(in: .vertical) {
            // iPad has the room: every page sits in the middle rather than hugging the top.
            if centered || sizeClass == .regular {
                padded
                    .frame(maxHeight: .infinity)
                    .offset(y: -16)
            }
            ScrollView { padded }
                .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 12) { actions }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Color(.systemBackground))
        }
    }

    private var padded: some View {
        content
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
    }
}

/// Headline and one supporting line.
struct OnboardingTitle: View {
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Thin segmented progress, one segment per step.
struct OnboardingProgress: View {
    var count: Int
    var current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(.fill.secondary))
                    .frame(height: 4)
            }
        }
        .animation(.smooth, value: current)
        .accessibilityElement()
        .accessibilityLabel(Text("Step \(current + 1) of \(count)"))
    }
}
