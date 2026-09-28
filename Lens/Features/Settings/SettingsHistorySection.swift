import SwiftData
import SwiftUI

/// History & privacy controls: saving, places, the lock, export and clearing.
struct SettingsHistorySection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @AppStorage(Pref.saveHistory) private var saveHistory = Pref.Default.saveHistory
    @AppStorage(Pref.rememberPlace) private var rememberPlace = Pref.Default.rememberPlace
    @AppStorage(Pref.requireFaceID) private var requireFaceID = Pref.Default.requireFaceID
    @Query(SettingsHistorySection.anyRecord) private var anyRecord: [ScanRecord]

    @State private var confirmingClear = false
    @State private var showingLocationDenied = false
    @State private var showingNoPasscode = false

    private let biometry = BiometryKind.current

    private static var anyRecord: FetchDescriptor<ScanRecord> {
        var descriptor = FetchDescriptor<ScanRecord>()
        descriptor.fetchLimit = 1
        return descriptor
    }

    var body: some View {
        let isEmpty = anyRecord.isEmpty

        Section {
            Toggle(isOn: $saveHistory) {
                SettingsLabel("Save History", symbol: "clock.fill", color: .gray)
            }
            Toggle(isOn: rememberPlaceBinding) {
                SettingsLabel("Remember where I scanned", symbol: "location.fill", color: .blue,
                              subtitle: "Place names only, kept on this iPhone")
            }
            Toggle(isOn: lockBinding) {
                SettingsLabel(biometry.requireTitle, symbol: biometry.symbol, color: .green)
            }
            ShareLink(
                item: HistoryExport(container: modelContext.container),
                preview: SharePreview(Text("Lens History"), image: Image(systemName: "tablecells"))
            ) {
                SettingsLabel("Export CSV", symbol: "tablecells.fill", color: .teal)
            }
            .foregroundStyle(.primary)
            .disabled(isEmpty)
            Button(role: .destructive) {
                confirmingClear = true
            } label: {
                Label {
                    Text("Clear History")
                } icon: {
                    SettingsGlyph(symbol: "trash.fill", color: isEmpty ? .gray : .red)
                }
            }
            .foregroundStyle(isEmpty ? Color.secondary : Palette.danger)
            .disabled(isEmpty)
        } header: {
            Text("History")
        } footer: {
            if !isEmpty {
                Text("^[\(recordCount) scan](inflect: true) on this iPhone. History never leaves your device.")
            }
        }
        .confirmationDialog("Clear History?", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("Clear History", role: .destructive, action: clearHistory)
        } message: {
            Text("Every scan and created code will be deleted from this iPhone. This can't be undone.")
        }
        .alert("Location Is Off for Lens", isPresented: $showingLocationDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To remember where you scan, allow location access while using Lens.")
        }
        .alert("Set Up a Passcode", isPresented: $showingNoPasscode) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("To lock History, set a passcode or Face ID on this iPhone first.")
        }
    }

    private var recordCount: Int {
        (try? modelContext.fetchCount(FetchDescriptor<ScanRecord>())) ?? 0
    }

    /// Turning it on asks for when-in-use location; it flips back off if that's declined.
    private var rememberPlaceBinding: Binding<Bool> {
        Binding {
            rememberPlace
        } set: { enabled in
            rememberPlace = enabled
            guard enabled else { return }
            Task {
                let service = LocationService.shared
                let granted = service.isDenied ? false : await service.requestAuthorization()
                if !granted {
                    rememberPlace = false
                    showingLocationDenied = true
                }
            }
        }
    }

    /// Changing the lock either way needs the owner to authenticate first.
    private var lockBinding: Binding<Bool> {
        Binding {
            requireFaceID
        } set: { enabled in
            guard HistoryLock.canAuthenticate else {
                showingNoPasscode = true
                return
            }
            Task {
                let reason = enabled
                    ? String(localized: "Lock your scan history.")
                    : String(localized: "Turn off the History lock.")
                guard await HistoryLock.authenticate(reason: reason) else { return }
                requireFaceID = enabled
                if enabled { HistoryLock.shared.markUnlocked() }
            }
        }
    }

    private func clearHistory() {
        try? modelContext.delete(model: ScanRecord.self)
        try? modelContext.save()
    }
}

#if DEBUG
#Preview {
    Form { SettingsHistorySection() }
        .modelContainer(HistorySamples.container)
}
#endif
