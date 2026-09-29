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
            Button(record.isPinned ? "Unpin" : "Pin to Your Codes", systemImage: record.isPinned ? "pin.slash" : "pin", action: togglePin)
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

/// Tile, title, where or what, when, and a small tag: the safety verdict or the format.
struct HistoryRow: View {
    let record: ScanRecord

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            KindTile(kind: record.kind)
                .overlay(alignment: .bottomTrailing) { flagBadge }
            if typeSize.isAccessibilitySize {
                stackedText
            } else {
                text
            }
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                title
                Spacer(minLength: 0)
                stamp
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                detailLine
                Spacer(minLength: 0)
                tag.fixedSize()
            }
        }
        .padding(.top, 1)
    }

    /// Accessibility sizes: one column, so the title keeps the full width.
    private var stackedText: some View {
        VStack(alignment: .leading, spacing: 4) {
            title
            detailLine
            HStack(spacing: 8) {
                stamp
                tag
            }
        }
    }

    private var title: some View {
        Text(record.historyTitle)
            .font(.body.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(typeSize.isAccessibilitySize ? 4 : 2)
    }

    private var stamp: some View {
        Text(HistoryBucket.stamp(for: record.createdAt))
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .fixedSize()
    }

    private var detailLine: some View {
        detail
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
    }

    /// A small warning disc on the tile's corner, so a flagged link reads as one before its text does.
    @ViewBuilder
    private var flagBadge: some View {
        if let level = record.safetyLevel, record.isFlagged {
            Image(systemName: level == .danger ? "xmark" : "exclamationmark")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(level == .danger ? Palette.danger : Palette.cautionFill, in: .circle)
                .background(Color(.secondarySystemGroupedBackground), in: .circle.inset(by: -2))
                .offset(x: 5, y: 5)
                .accessibilityHidden(true)
        }
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
        switch record.safetyLevel {
        case .danger:
            Label("Danger", systemImage: "xmark.octagon.fill")
                .labelStyle(CompactLabelStyle())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.danger)
        case .caution:
            Label("Caution", systemImage: "exclamationmark.triangle.fill")
                .labelStyle(CompactLabelStyle())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.caution)
        case .safe:
            Label("Safe", systemImage: "checkmark.shield.fill")
                .labelStyle(CompactLabelStyle())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.safe)
        default:
            if record.symbology != .qr {
                Text(record.symbology.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.fill.tertiary, in: .capsule)
            }
        }
    }
}

private extension Palette {
    /// Caution as a fill behind a white glyph (the text-weight caution color is too dark in light
    /// mode and too light in dark mode to carry white).
    static let cautionFill = Color(light: 0xC77C02, dark: 0xB8860B)
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
