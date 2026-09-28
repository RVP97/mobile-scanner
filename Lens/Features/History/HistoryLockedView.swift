import SwiftUI

/// Shown instead of History until the owner authenticates. Asks right away when it appears.
struct HistoryLockedView: View {
    private let lock = HistoryLock.shared
    private let biometry = BiometryKind.current

    var body: some View {
        ContentUnavailableView {
            Label("History Is Locked", systemImage: "lock.fill")
        } description: {
            Text("Your scans stay hidden until you unlock.")
        } actions: {
            Button {
                Task { await lock.unlock() }
            } label: {
                Label("Unlock", systemImage: biometry.symbol)
            }
            .buttonStyle(.borderedProminent)
            .disabled(lock.isAuthenticating)
        }
        .task { await lock.unlock() }
    }
}

#if DEBUG
#Preview {
    HistoryLockedView()
}
#endif
