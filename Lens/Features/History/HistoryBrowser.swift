import SwiftData
import SwiftUI

/// History at the large detent: search, filter chips, day sections, select mode.
struct HistoryBrowser: View {
    var isLocked: Bool

    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @AppStorage(Pref.saveHistory) private var saveHistory = Pref.Default.saveHistory
    @AppStorage(Pref.requireFaceID) private var requireFaceID = Pref.Default.requireFaceID
    @Query(HistoryBrowser.anyRecord) private var anyRecord: [ScanRecord]

    @State private var criteria = HistoryCriteria()
    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<UUID>()
    @State private var codePreview: ScanRecord?
    @State private var confirmingDelete = false

    private static var anyRecord: FetchDescriptor<ScanRecord> {
        var descriptor = FetchDescriptor<ScanRecord>()
        descriptor.fetchLimit = 1
        return descriptor
    }

    private var isEditing: Bool { editMode.isEditing }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("History")
                .historySubtitle(isLocked || anyRecord.isEmpty ? nil : recordCountText)
                .toolbar { toolbar }
                .environment(\.editMode, $editMode)
                .sheet(item: $codePreview) { CodePreviewSheet(record: $0) }
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
                    showCode: { codePreview = $0 }
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
                Button("Open Settings") { model.modal = .settings }
            }
        }
    }

    private var recordCountText: Text {
        let count = (try? modelContext.fetchCount(FetchDescriptor<ScanRecord>())) ?? 0
        return Text("^[\(count) scan](inflect: true)")
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            if isEditing {
                Button("Done") { setEditing(false) }
                    .fontWeight(.semibold)
            } else if !isLocked && !anyRecord.isEmpty {
                Button("Select") { setEditing(true) }
            }
            if requireFaceID && !isLocked && !isEditing {
                Button("Lock History", systemImage: "lock.fill") { HistoryLock.shared.lock() }
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if !isEditing {
                Button("Create Code", systemImage: "plus") { model.modal = .create }
                Button("Settings", systemImage: "gearshape") { model.modal = .settings }
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
    HistoryBrowser(isLocked: false)
        .environment(AppModel())
        .modelContainer(HistorySamples.container)
}
#endif
