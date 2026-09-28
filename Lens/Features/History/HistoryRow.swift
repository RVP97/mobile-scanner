import SwiftData
import SwiftUI

/// A History row with its gestures: tap to open, swipe to pin or delete, press for more.
struct HistoryRowItem: View {
    let record: ScanRecord
    let isEditing: Bool
    let actions: HistoryRowActions

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if isEditing {
                HistoryRow(record: record)
            } else {
                Button { actions.open(record) } label: {
                    HistoryRow(record: record)
                }
                .buttonStyle(.plain)
            }
        }
        .tag(record.id)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: togglePin) {
                Label(record.isPinned ? "Unpin" : "Pin", systemImage: record.isPinned ? "pin.slash" : "pin")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: delete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = record.raw
            }
            ShareLink(item: record.raw) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button("Show Code", systemImage: "qrcode") { actions.showCode(record) }
            Button(record.isPinned ? "Unpin" : "Pin", systemImage: record.isPinned ? "pin.slash" : "pin", action: togglePin)
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: delete)
        }
        .sensoryFeedback(.selection, trigger: record.isPinned)
    }

    private func togglePin() {
        withAnimation(.snappy) { record.isPinned.toggle() }
    }

    private func delete() {
        withAnimation(.snappy) { modelContext.delete(record) }
    }
}

/// Tile, title, where or what, when, and a small format tag.
struct HistoryRow: View {
    let record: ScanRecord

    var body: some View {
        HStack(spacing: 12) {
            KindTile(kind: record.kind)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(record.historyTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(HistoryBucket.stamp(for: record.createdAt))
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    detail
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    tag
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var detail: some View {
        if let place = record.placeName {
            Label(place, systemImage: "location.fill")
                .labelStyle(CompactLabelStyle())
        } else if !record.subtitle.isEmpty {
            Text(record.subtitle)
        } else {
            if record.origin == .created {
                Text("Created \(Text(record.kind.title))")
            } else {
                Text(record.kind.title)
            }
        }
    }

    @ViewBuilder
    private var tag: some View {
        if record.isVerifiedSafe {
            Label("Safe", systemImage: "checkmark.shield.fill")
                .labelStyle(CompactLabelStyle())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.safe)
        } else if record.symbology != .qr {
            Text(record.symbology.displayName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.fill.tertiary, in: .capsule)
        }
    }
}

/// Small leading glyph hugging its text, for secondary lines.
private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}

#if DEBUG
#Preview {
    List {
        ForEach(HistorySamples.records()) { HistoryRow(record: $0) }
    }
    .modelContainer(HistorySamples.container)
}
#endif
