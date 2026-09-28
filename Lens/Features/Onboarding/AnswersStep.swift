import SwiftUI

/// "Every code gets its own answer": the kind tiles, each with the action it leads to.
struct AnswersStep: View {
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    private let examples: [(kind: CodeKind, example: LocalizedStringKey)] = [
        (.link, "atlas-coffee.co"),
        (.wifi, "Atlas Guest"),
        (.product, "Fine-liner Pen"),
        (.travel, "MEX → SFO"),
        (.contact, "Maya Chen"),
        (.text, "Locker 214"),
    ]

    var body: some View {
        OnboardingPage {
            VStack(spacing: 32) {
                OnboardingTitle(
                    title: "Every code gets its own answer",
                    subtitle: "Lens knows what it’s looking at, so the next step is always one tap."
                )
                VStack(spacing: 16) {
                    ForEach(Array(examples.enumerated()), id: \.offset) { index, item in
                        row(item.kind, example: item.example)
                            .opacity(revealed ? 1 : 0)
                            .offset(y: revealed ? 0 : 16)
                            .animation(reduceMotion ? nil : .smooth(duration: 0.5).delay(Double(index) * 0.06), value: revealed)
                    }
                }
            }
        } actions: {
            Button("Continue", action: onContinue)
                .buttonStyle(.primaryAction())
        }
        .onAppear { revealed = true }
    }

    private func row(_ kind: CodeKind, example: LocalizedStringKey) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                KindTile(kind: kind, size: 56)
                labels(kind, example: example)
                Spacer(minLength: 8)
                AnswerVerbPill(kind: kind)
            }
            HStack(spacing: 16) {
                KindTile(kind: kind, size: 56)
                VStack(alignment: .leading, spacing: 8) {
                    labels(kind, example: example)
                    AnswerVerbPill(kind: kind)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func labels(_ kind: CodeKind, example: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kind.title)
                .font(.headline)
            Text(example)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    AnswersStep {}
}
