import SwiftUI

/// Last step: put Lens one press away, and choose whether safe links open instantly.
struct EverywhereStep: View {
    var onFinish: () -> Void

    @AppStorage(Pref.scanAndGo) private var scanAndGo = Pref.Default.scanAndGo

    var body: some View {
        OnboardingPage {
            VStack(spacing: 24) {
                OnboardingTitle(
                    title: "Scan faster from anywhere",
                    subtitle: "Put Lunet one press away, even when your iPhone is locked."
                )
                EverywhereSetupList()
                Toggle(isOn: $scanAndGo) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open links instantly")
                            .font(.headline)
                        Text("Scan & Go · only links that pass the safety check")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(Palette.accent)
                .padding(16)
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 20, style: .continuous))
                Text("Change any of these later in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } actions: {
            Button("Start Scanning", action: onFinish)
                .buttonStyle(.primaryAction())
        }
    }
}

#Preview {
    EverywhereStep {}
}
