import SwiftUI

/// Settings, presented as a modal from Home or History.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(Pref.haptics) private var haptics = Pref.Default.haptics
    @AppStorage(Pref.sound) private var sound = Pref.Default.sound
    @AppStorage(Pref.scanAndGo) private var scanAndGo = Pref.Default.scanAndGo
    @AppStorage(Pref.multiScan) private var multiScan = Pref.Default.multiScan
    @AppStorage(Pref.autoCopy) private var autoCopy = Pref.Default.autoCopy
    @AppStorage(Pref.checkLinks) private var checkLinks = Pref.Default.checkLinks
    @AppStorage(Pref.deepLinkCheck) private var deepLinkCheck = Pref.Default.deepLinkCheck
    @AppStorage(Pref.blockDangerous) private var blockDangerous = Pref.Default.blockDangerous
    @AppStorage(Pref.appearance) private var appearance = Pref.Default.appearance

    @State private var path: [SettingsRoute] = SettingsView.initialPath

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                scanAnywhereSection
                scanningSection
                safetySection
                SettingsHistorySection()
                appearanceSection
                SettingsLanguageSection()
                SettingsAboutSection()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .scanAnywhere: ScanAnywhereView()
                case .privacy: PrivacyView()
                }
            }
        }
        .tint(Palette.accent)
    }

    /// The one thing worth promoting: Lens outside the app.
    private var scanAnywhereSection: some View {
        Section {
            NavigationLink(value: SettingsRoute.scanAnywhere) {
                HStack(spacing: 16) {
                    EverywhereIllustration(shortcut: .controlCenter, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan from Anywhere")
                            .font(.headline)
                        Text("Control Center, Lock Screen and the Action button")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var scanningSection: some View {
        Section {
            Toggle(isOn: $scanAndGo) {
                SettingsLabel("Scan & Go", symbol: "bolt.fill", color: .orange,
                              subtitle: "Open links instantly when they pass the safety check")
            }
            Toggle(isOn: $multiScan) {
                SettingsLabel("Start in Multi-scan", symbol: "square.stack.3d.up.fill", color: .indigo)
            }
            Toggle(isOn: $autoCopy) {
                SettingsLabel("Auto-copy", symbol: "doc.on.doc.fill", color: .blue)
            }
            Toggle(isOn: $haptics) {
                SettingsLabel("Haptics", symbol: "iphone.radiowaves.left.and.right", color: .pink)
            }
            Toggle(isOn: $sound) {
                SettingsLabel("Sound", symbol: "speaker.wave.2.fill", color: .red)
            }
        } header: {
            Text("Scanning")
        }
    }

    private var safetySection: some View {
        Section {
            Toggle(isOn: $checkLinks) {
                SettingsLabel("Check links before opening", symbol: "checkmark.shield.fill", color: .green)
            }
            Toggle(isOn: $deepLinkCheck) {
                SettingsLabel("Deep check", symbol: "point.3.connected.trianglepath.dotted", color: .teal)
            }
            .disabled(!checkLinks)
            Toggle(isOn: $blockDangerous) {
                SettingsLabel("Block dangerous links", symbol: "hand.raised.fill", color: .red)
            }
        } header: {
            Text("Safety")
        } footer: {
            Text("Deep check follows redirects and looks up the domain's age by contacting the link's own server. Nothing is sent to Lens.")
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Appearance", selection: $appearance) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    private static var initialPath: [SettingsRoute] {
#if DEBUG
        defer { QAHarness.settingsPath = [] }
        return QAHarness.settingsPath
#else
        return []
#endif
    }
}

/// Opens the system's per-app language screen and shows the language in use.
private struct SettingsLanguageSection: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                HStack {
                    LabeledContent {
                        Text(currentLanguage)
                    } label: {
                        SettingsLabel("Language", symbol: "globe", color: .blue)
                    }
                    Image(systemName: "arrow.up.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(.primary)
            .accessibilityHint("Opens Lens in the Settings app")
        } footer: {
            Text("Lens follows your iPhone's language. You can choose a different one for Lens in the Settings app.")
        }
    }

    private var currentLanguage: String {
        let code = Bundle.main.preferredLocalizations.first ?? Locale.current.identifier
        return Locale.current.localizedString(forIdentifier: code)?.localizedCapitalized ?? code
    }
}

#if DEBUG
#Preview {
    SettingsView()
        .modelContainer(HistorySamples.container)
}
#endif
