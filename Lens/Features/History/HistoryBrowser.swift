import SwiftData
import SwiftUI

/// History, pushed from Home: search, filter chips, day sections, select mode.
struct HistoryBrowser: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @AppStorage(Pref.saveHistory) private var saveHistory = Pref.Default.saveHistory
    @AppStorage(Pref.requireFaceID) private var requireFaceID = Pref.Default.requireFaceID
    @Query(HistoryBrowser.anyRecord) private var anyRecord: [ScanRecord]

    @State private var criteria = HistoryBrowser.initialCriteria
    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<UUID>()
    @State private var confirmingDelete = false

    private static var anyRecord: FetchDescriptor<ScanRecord> {
        var descriptor = FetchDescriptor<ScanRecord>()
        descriptor.fetchLimit = 1
        return descriptor
    }

    private let lock = HistoryLock.shared

    private static var initialCriteria: HistoryCriteria {
        #if DEBUG
        return QAHarness.historyCriteria
        #else
        return HistoryCriteria()
        #endif
    }

    private var isEditing: Bool { editMode.isEditing }
    private var isLocked: Bool { requireFaceID && !lock.isUnlocked }

    var body: some View {
        content
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .historySubtitle(isLocked || anyRecord.isEmpty ? nil : recordCountText)
            .toolbar { toolbar }
            .navigationBarBackButtonHidden(isEditing)
            .environment(\.editMode, $editMode)
            .background(Color(.systemGroupedBackground))
            .confirmationDialog(
                Text("Delete ^[\(selection.count) item](inflect: true)?"),
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive, action: deleteSelection)
            } message: {
                Text("They'll be removed from this iPhone.")
            }
    }

    @ViewBuilder
    private var content: some View {
        if isLocked {
            HistoryLockedView()
        } else if anyRecord.isEmpty {
            emptyHistory
        } else {
            HistoryResults(
                criteria: $criteria,
                selection: $selection,
                isEditing: isEditing,
                isSaving: saveHistory,
                actions: HistoryRowActions(
                    open: { model.show($0.scanResult) },
                    showCode: { model.codeOnDisplay = ShowCodeItem(record: $0) }
                )
            )
            .searchable(text: $criteria.search, prompt: Text("Search scans and places"))
        }
    }

    @ViewBuilder
    private var emptyHistory: some View {
        if saveHistory {
            ContentUnavailableView {
                Label("No Scans Yet", systemImage: "qrcode.viewfinder")
            } description: {
                Text("Codes you scan or create show up here.")
            }
        } else {
            ContentUnavailableView {
                Label("History Is Off", systemImage: "clock.arrow.circlepath")
            } description: {
                Text("Turn on Save History to keep the codes you scan on this iPhone.")
            } actions: {
                Button("Open Settings") { model.openSettings() }
            }
        }
    }

    private var recordCountText: Text {
        let count = (try? modelContext.fetchCount(FetchDescriptor<ScanRecord>())) ?? 0
        return Text("^[\(count) scan](inflect: true)")
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if isEditing {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { setEditing(false) }
                    .fontWeight(.semibold)
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if requireFaceID && !isLocked && !isEditing {
                Button("Lock History", systemImage: "lock.fill") { HistoryLock.shared.lock() }
            }
            if !isEditing && !isLocked && !anyRecord.isEmpty {
                Button("Select") { setEditing(true) }
            }
        }
        if isEditing {
            ToolbarItemGroup(placement: .bottomBar) {
                ShareLink(
                    item: HistoryExport(container: modelContext.container, ids: selection),
                    preview: SharePreview(Text("Lunet History"), image: Image(systemName: "tablecells"))
                ) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(selection.isEmpty)
                Spacer()
                Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                    .disabled(selection.isEmpty)
            }
        }
    }

    private func setEditing(_ editing: Bool) {
        withAnimation(.snappy) {
            editMode = editing ? .active : .inactive
            if !editing { selection.removeAll() }
        }
    }

    private func deleteSelection() {
        let ids = Array(selection)
        let doomed = (try? modelContext.fetch(FetchDescriptor<ScanRecord>(predicate: #Predicate { ids.contains($0.id) }))) ?? []
        doomed.forEach(modelContext.delete)
        setEditing(false)
    }
}

private extension View {
    /// "128 scans" under the large title where the system supports navigation subtitles.
    @ViewBuilder
    func historySubtitle(_ subtitle: Text?) -> some View {
        if #available(iOS 26.0, *), let subtitle {
            navigationSubtitle(subtitle)
        } else {
            self
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { HistoryBrowser() }
        .environment(AppModel())
        .modelContainer(HistorySamples.container)
}
#endif
