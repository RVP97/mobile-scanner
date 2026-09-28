import SwiftUI

/// "Scan faster from anywhere": the places Lens can live outside the app, each with a guide.
/// Used by onboarding; Settings can show it too.
struct EverywhereSetupList: View {
    @State private var guide: EverywhereShortcut?

    var body: some View {
        VStack(spacing: 12) {
            ForEach(EverywhereShortcut.availableHere) { shortcut in
                row(shortcut)
            }
        }
        .sheet(item: $guide) { shortcut in
            EverywhereGuide(shortcut: shortcut)
        }
    }

    private func row(_ shortcut: EverywhereShortcut) -> some View {
        HStack(spacing: 16) {
            EverywhereIllustration(shortcut: shortcut, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.title)
                    .font(.headline)
                Text(shortcut.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(shortcut.buttonTitle) { guide = shortcut }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(Palette.accent)
                .accessibilityHint(Text("Shows how to add Lens here."))
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 20, style: .continuous))
    }
}

/// Step-by-step directions for one place. Apps can't add controls or widgets themselves.
struct EverywhereGuide: View {
    var shortcut: EverywhereShortcut
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    EverywhereIllustration(shortcut: shortcut, size: 96)
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(shortcut.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(index + 1, format: .number)
                                    .font(.subheadline.weight(.bold))
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.accent)
                                    .frame(width: 28, height: 28)
                                    .background(Palette.accent.opacity(0.16), in: .circle)
                                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                                Text(step)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle(shortcut.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview("List") {
    EverywhereSetupList()
        .padding()
}

#Preview("Guide") {
    EverywhereGuide(shortcut: .controlCenter)
}
