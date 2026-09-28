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

    var body: some View {
        NavigationStack {
            Form {
                scanningSection
                scanAndGoSection
                safetySection
                SettingsHistorySection()
                appearanceSection
                SettingsLanguageSection()
                Section {
                    NavigationLink {
                        ScanAnywhereView()
                    } label: {
                        Label("Scan from Anywhere", systemImage: "apps.iphone")
                    }
                }
                SettingsAboutSection()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var scanningSection: some View {
        Section("Scanning") {
            Toggle("Haptics", isOn: $haptics)
            Toggle("Sound", isOn: $sound)
            Toggle("Start in Multi-scan", isOn: $multiScan)
            Toggle("Auto-copy", isOn: $autoCopy)
        }
    }

    private var scanAndGoSection: some View {
        Section {
            Toggle("Scan & Go", isOn: $scanAndGo)
        } footer: {
            Text("Opens links instantly when they pass the safety check.")
        }
    }

    private var safetySection: some View {
        Section {
            Toggle("Check links before opening", isOn: $checkLinks)
            Toggle("Deep check", isOn: $deepLinkCheck)
                .disabled(!checkLinks)
            Toggle("Block dangerous links", isOn: $blockDangerous)
        } header: {
            Text("Safety")
        } footer: {
            Text("Deep check follows redirects and checks domain age by contacting the link's server. Nothing is sent to Lens.")
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
                    LabeledContent("Language", value: currentLanguage)
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
