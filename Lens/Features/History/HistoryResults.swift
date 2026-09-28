import SwiftData
import SwiftUI

/// What a row can ask its screen to do.
struct HistoryRowActions {
    var open: (ScanRecord) -> Void
    var showCode: (ScanRecord) -> Void
}

/// The filtered list. Each section runs its own query against the store, so sectioning never
/// loads or sorts the whole history in memory.
struct HistoryResults: View {
    @Binding var criteria: HistoryCriteria
    @Binding var selection: Set<UUID>
    var isEditing: Bool
    var isSaving: Bool
    var actions: HistoryRowActions

    @Query private var probe: [ScanRecord]

    init(
        criteria: Binding<HistoryCriteria>,
        selection: Binding<Set<UUID>>,
        isEditing: Bool,
        isSaving: Bool,
        actions: HistoryRowActions
    ) {
        _criteria = criteria
        _selection = selection
        self.isEditing = isEditing
        self.isSaving = isSaving
        self.actions = actions
        var descriptor = FetchDescriptor<ScanRecord>(predicate: criteria.wrappedValue.predicate())
        descriptor.fetchLimit = 1
        _probe = Query(descriptor)
    }

    var body: some View {
        let now = Date.now
        let pinnedOnly = criteria.filter == .pinned

        List(selection: $selection) {
            Section {
                HistoryFilterBar(selection: $criteria.filter)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } footer: {
                if !isSaving {
                    Label("History is off. New scans aren't saved.", systemImage: "pause.circle")
                        .padding(.top, 8)
                }
            }

            if !pinnedOnly {
                HistorySection(
                    title: "Pinned",
                    predicate: criteria.predicate(pinned: true),
                    isEditing: isEditing,
                    actions: actions
                )
            }
            ForEach(HistoryBucket.allCases, id: \.self) { bucket in
                HistorySection(
                    title: bucket.title,
                    predicate: criteria.predicate(in: bucket.range(now: now), pinned: pinnedOnly),
                    isEditing: isEditing,
                    actions: actions
                )
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if probe.isEmpty {
                emptyState
                    .padding(.top, 72)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !criteria.trimmedSearch.isEmpty {
            ContentUnavailableView.search(text: criteria.trimmedSearch)
        } else {
            switch criteria.filter {
            case .pinned:
                ContentUnavailableView {
                    Label("No Pinned Codes", systemImage: "pin")
                } description: {
                    Text("Swipe right on a code to keep it at the top.")
                }
            case .created:
                ContentUnavailableView {
                    Label("Nothing Created Yet", systemImage: "qrcode")
                } description: {
                    Text("Codes you make with Create appear here.")
                }
            default:
                ContentUnavailableView {
                    Label("No Matches", systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text("Nothing in History matches this filter.")
                }
            }
        }
    }
}

/// One titled group of rows, hidden when empty.
private struct HistorySection: View {
    let title: LocalizedStringResource
    let isEditing: Bool
    let actions: HistoryRowActions

    @Query private var records: [ScanRecord]

    init(title: LocalizedStringResource, predicate: Predicate<ScanRecord>, isEditing: Bool, actions: HistoryRowActions) {
        self.title = title
        self.isEditing = isEditing
        self.actions = actions
        _records = Query(filter: predicate, sort: \.createdAt, order: .reverse)
    }

    var body: some View {
        if !records.isEmpty {
            Section {
                ForEach(records) { record in
                    HistoryRowItem(record: record, isEditing: isEditing, actions: actions)
                }
            } header: {
                Text(title)
            }
        }
    }
}
