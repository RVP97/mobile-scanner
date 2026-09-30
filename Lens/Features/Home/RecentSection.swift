import SwiftData
import SwiftUI

/// The last few scans, and the way into History.
struct RecentSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @AppStorage(Pref.saveHistory) private var saveHistory = Pref.Default.saveHistory
    @Query(RecentSection.descriptor) private var recent: [ScanRecord]
    @State private var swipeGate = SwipeGate()

    static let limit = 5

    private static var descriptor: FetchDescriptor<ScanRecord> {
        let scanned = ScanRecord.Origin.scanned.rawValue
        var descriptor = FetchDescriptor<ScanRecord>(
            predicate: #Predicate { $0.originRaw == scanned },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return descriptor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "Recent") {
                if !recent.isEmpty {
                    Button("See All") { model.path = [.history] }
                        .accessibilityLabel("See All History")
                }
            }
            if recent.isEmpty {
                emptyState
            } else {
                rows
            }
        }
        .padding(.horizontal, 20)
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(recent) { record in
                Button {
                    if !swipeGate.isSwiping { model.show(record.scanResult) }
                } label: {
                    HistoryRow(record: record)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(.rect)
                }
                .buttonStyle(RowPressStyle())
                .background(Color(.secondarySystemGroupedBackground))
                .contextMenu { menu(for: record) }
                .swipeToDelete(gate: swipeGate) {
                    withAnimation(.snappy) { modelContext.delete(record) }
                }
                if record.id != recent.last?.id {
                    Divider().padding(.leading, 72)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20, style: .continuous))
        .clipShape(.rect(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func menu(for record: ScanRecord) -> some View {
        Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = record.raw }
        ShareLink(item: record.raw) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        Button("Show Code", systemImage: "qrcode") { model.codeOnDisplay = ShowCodeItem(record: record) }
        Button(
            record.isPinned ? "Unpin" : "Pin to Your Codes",
            systemImage: record.isPinned ? "pin.slash" : "pin"
        ) {
            withAnimation(.snappy) { record.isPinned.toggle() }
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) {
            withAnimation(.snappy) { modelContext.delete(record) }
        }
    }

    private var emptyState: some View {
        HStack(spacing: 16) {
            Image(systemName: saveHistory ? "clock" : "clock.badge.xmark")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(.fill.tertiary, in: .rect(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(saveHistory ? "Nothing scanned yet" : "History is off")
                    .font(.headline)
                Text(saveHistory ? "Tap Scan and point at any code. It’ll be here for next time." : "New scans aren’t saved. You can turn this on in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Highlights a row while pressed, like a list cell.
struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color(.systemFill) : .clear)
    }
}

#if DEBUG
#Preview {
    ScrollView { RecentSection() }
        .background(Color(.systemGroupedBackground))
        .environment(AppModel())
        .modelContainer(HistorySamples.container)
}
#endif
