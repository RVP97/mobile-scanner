import SwiftUI

/// Shown instead of History until the owner authenticates. Asks right away when it appears.
struct HistoryLockedView: View {
    private let lock = HistoryLock.shared
    private let biometry = BiometryKind.current

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 72, height: 72)
                .background(.fill.tertiary, in: .circle)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("History Is Locked")
                    .font(.title2.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                Text("Your scans stay hidden until you unlock.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            Button {
                Task { await lock.unlock() }
            } label: {
                Label("Unlock", systemImage: biometry.symbol)
                    .padding(.horizontal, 40)
            }
            .buttonStyle(.primaryAction())
            .fixedSize()
            .disabled(lock.isAuthenticating)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: -40)
        .task {
#if DEBUG
            if QAHarness.suppressesAuthPrompt { return }
#endif
            await lock.unlock()
        }
    }
}

#if DEBUG
#Preview {
    HistoryLockedView()
}
#endif
