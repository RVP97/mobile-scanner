import SwiftUI

/// How to reach the scanner without finding the app icon: Control Center, Lock Screen,
/// the Action button and Home Screen widgets.
struct ScanAnywhereView: View {
    var body: some View {
        List {
            Section {
                Text("The fastest scan is the one where you never look for the app. Add Lens where your thumb already is.")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
            }

            if #available(iOS 18.0, *) {
                ScanPlace(
                    symbol: "switch.2",
                    title: "Control Center",
                    steps: [
                        "Swipe down from the top-right corner.",
                        "Touch and hold an empty space, then tap Add a Control.",
                        "Search for Lens and add its Scan control.",
                    ]
                )
                ScanPlace(
                    symbol: "lock.iphone",
                    title: "Lock Screen",
                    steps: [
                        "Touch and hold the Lock Screen, then tap Customize.",
                        "Tap a control at the bottom and remove it.",
                        "Tap the empty spot and choose the Lens Scan control.",
                    ]
                )
            }

            ScanPlace(
                symbol: "button.programmable",
                title: "Action button",
                steps: [
                    "Open Settings › Action Button.",
                    "Swipe to Shortcut or Controls.",
                    "Choose the Lens Scan control.",
                ],
                note: "On iPhone 15 Pro and later."
            )

            ScanPlace(
                symbol: "widget.small",
                title: "Home Screen widget",
                steps: [
                    "Touch and hold the Home Screen, then tap Edit › Add Widget.",
                    "Search for Lens.",
                    "Pick a size and tap Add Widget.",
                ]
            )
        }
        .navigationTitle("Scan from Anywhere")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ScanPlace: View {
    let symbol: String
    let title: LocalizedStringKey
    let steps: [LocalizedStringKey]
    var note: LocalizedStringKey?

    var body: some View {
        Section {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 56, height: 56)
                    .background(Palette.accent.opacity(0.14), in: .rect(cornerRadius: 16, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    if let note {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)

            ForEach(steps.indices, id: \.self) { index in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(index + 1, format: .number)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .trailing)
                    Text(steps[index])
                        .font(.subheadline)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { ScanAnywhereView() }
}
#endif
