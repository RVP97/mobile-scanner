import SwiftUI

/// How to reach the scanner without finding the app icon: Control Center, Lock Screen,
/// the Action button and Home Screen widgets. Same places and wording as onboarding.
struct ScanAnywhereView: View {
    private static let widgetSteps: [LocalizedStringKey] = [
        "Touch and hold the Home Screen, then tap Edit › Add Widget.",
        "Search for Ojito.",
        "Pick a size and tap Add Widget.",
    ]

    var body: some View {
        List {
            Section {
                Text("The fastest scan is the one where you never look for the app. Put Ojito where your thumb already is.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 4))
            }

            ForEach(EverywhereShortcut.availableHere) { shortcut in
                ScanPlace(title: shortcut.title, summary: shortcut.summary, steps: shortcut.steps) {
                    EverywhereIllustration(shortcut: shortcut, size: 56)
                }
            }

            ScanPlace(title: "Home Screen Widget", summary: "One tap from your Home Screen.", steps: Self.widgetSteps) {
                WidgetIllustration(size: 56)
            }
        }
        .navigationTitle("Scan from Anywhere")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ScanPlace<Illustration: View>: View {
    let title: LocalizedStringKey
    let summary: LocalizedStringKey
    let steps: [LocalizedStringKey]
    @ViewBuilder var illustration: Illustration

    var body: some View {
        Section {
            HStack(spacing: 16) {
                illustration
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(steps.indices, id: \.self) { index in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(index + 1, format: .number)
                            .font(.footnote.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Palette.accent)
                            .frame(width: 24, height: 24)
                            .background(Palette.accent.opacity(0.14), in: .circle)
                            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                        Text(steps[index])
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

/// A Home Screen slice with the Lens widget lit up, drawn like the other shortcut illustrations.
private struct WidgetIllustration: View {
    var size: CGFloat

    var body: some View {
        let unit = size / 64
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(Color(white: 0.1))
            Grid(horizontalSpacing: 5 * unit, verticalSpacing: 5 * unit) {
                GridRow {
                    RoundedRectangle(cornerRadius: 9 * unit, style: .continuous)
                        .fill(Palette.accent)
                        .frame(width: 45 * unit, height: 20 * unit)
                        .overlay {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 11 * unit, weight: .semibold))
                                .foregroundStyle(.black)
                        }
                        .gridCellColumns(2)
                }
                GridRow {
                    RoundedRectangle(cornerRadius: 6 * unit, style: .continuous)
                        .fill(.white.opacity(0.16))
                        .frame(width: 20 * unit, height: 20 * unit)
                    RoundedRectangle(cornerRadius: 6 * unit, style: .continuous)
                        .fill(.white.opacity(0.16))
                        .frame(width: 20 * unit, height: 20 * unit)
                }
            }
        }
        .frame(width: size, height: size)
        .environment(\.colorScheme, .dark)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    NavigationStack { ScanAnywhereView() }
}
#endif
