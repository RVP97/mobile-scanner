import SwiftUI

/// "Ojito checks every link first": a replay of a dangerous sticker being caught, next to an
/// ordinary link passing.
struct SafetyStep: View {
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Pref.haptics) private var haptics = Pref.Default.haptics
    /// How far the replay has got: 0 nothing, 1–3 hops revealed, 4 verdict, 5 safe card.
    @State private var stage = 0
    @State private var replayID = 0

    var body: some View {
        OnboardingPage {
            VStack(spacing: 24) {
                OnboardingTitle(
                    title: "Ojito checks every link first",
                    subtitle: "See where a code really goes, before anything opens."
                )
                VStack(spacing: 12) {
                    DangerReplayCard(stage: stage, onReplay: replay)
                    SafeLinkCard()
                        .opacity(stage >= 5 ? 1 : 0.35)
                }
                Label {
                    Text("Checks run on your iPhone. Ojito never collects what you scan.")
                } icon: {
                    Image(systemName: "lock.shield")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } actions: {
            Button("Continue", action: onContinue)
                .buttonStyle(.primaryAction())
        }
        .sensoryFeedback(.warning, trigger: stage) { _, new in new == 4 && haptics }
        .task(id: replayID) { await play() }
    }

    private func play() async {
        guard !reduceMotion else {
            stage = 5
            return
        }
        stage = 0
        for next in 1...5 {
            try? await Task.sleep(for: .milliseconds(next == 1 ? 350 : 520))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy) { stage = next }
        }
    }

    private func replay() {
        replayID += 1
    }
}

/// The parking-meter sticker whose link hides a lookalike domain.
private struct DangerReplayCard: View {
    var stage: Int
    var onReplay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                MicroLabel("Parking-meter sticker")
                Spacer()
                if stage >= 4 {
                    StatusPill(text: "Danger", symbol: "xmark.octagon.fill", tint: Palette.danger)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .frame(minHeight: 28)

            VStack(alignment: .leading, spacing: 0) {
                hop(1, label: "Shown on the sticker", symbol: "eye") {
                    Text(verbatim: "northbank-secure-pay.co")
                }
                hop(2, label: "Hidden hop", symbol: "arrow.turn.down.right") {
                    Text(verbatim: "bit.ly/3xQ…")
                }
                hop(3, label: "Actually opens", symbol: "exclamationmark.triangle.fill", isLast: true) {
                    VStack(alignment: .leading, spacing: 2) {
                        lookalikeDomain
                        Text("A zero, not an “o”")
                            .font(.caption)
                            .monospaced(false)
                            .foregroundStyle(Palette.danger)
                    }
                }
            }

            if stage >= 4 {
                HStack {
                    Label("Stopped before opening", systemImage: "hand.raised.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.danger)
                    Spacer()
                    Button("Replay", systemImage: "arrow.counterclockwise", action: onReplay)
                        .labelStyle(.iconOnly)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .opacity(stage >= 5 ? 1 : 0)
                }
                .transition(.opacity)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Palette.danger.opacity(stage >= 4 ? 0.5 : 0), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var lookalikeDomain: some View {
        HStack(spacing: 0) {
            Text(verbatim: "n")
            Text(verbatim: "0")
                .foregroundStyle(Palette.danger)
                .padding(.horizontal, 2)
                .background(Palette.danger.opacity(stage >= 3 ? 0.18 : 0), in: .rect(cornerRadius: 4))
            Text(verbatim: "rthbank-login.co")
        }
    }

    private func hop<Value: View>(
        _ number: Int,
        label: LocalizedStringKey,
        symbol: String,
        isLast: Bool = false,
        @ViewBuilder value: () -> Value
    ) -> some View {
        let visible = stage >= number
        let tint = isLast ? Palette.danger : Color.secondary
        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.14), in: .circle)
                if !isLast {
                    Rectangle()
                        .fill(.separator)
                        .frame(width: 1.5)
                        .frame(minHeight: 12, maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                value()
                    .font(.subheadline.weight(.medium))
                    .monospaced()
            }
            .padding(.bottom, isLast ? 0 : 12)
            Spacer(minLength: 0)
        }
        .opacity(visible ? 1 : 0.25)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// A café menu link that passes every check.
private struct SafeLinkCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                KindTile(kind: .link, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    MicroLabel("Café menu")
                    Text(verbatim: "atlas-coffee.co")
                        .font(.subheadline.weight(.medium))
                        .monospaced()
                }
                Spacer(minLength: 8)
                StatusPill(text: "Looks Safe", symbol: "checkmark.shield.fill", tint: Palette.safe)
            }
            HStack(spacing: 8) {
                fact("HTTPS", symbol: "lock.fill")
                fact("Since 2019", symbol: "calendar")
                fact("No redirects", symbol: "arrow.right")
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func fact(_ text: LocalizedStringKey, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

#Preview {
    SafetyStep {}
}
