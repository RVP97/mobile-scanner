import SwiftData
import SwiftUI

/// The peek detent: the latest scan as one calm row, and a quiet way into History.
struct HistoryPeek: View {
    var isLocked: Bool

    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @Query(HistoryPeek.recentScans) private var recent: [ScanRecord]

    private static var recentScans: FetchDescriptor<ScanRecord> {
        let scanned = ScanRecord.Origin.scanned.rawValue
        var descriptor = FetchDescriptor<ScanRecord>(
            predicate: #Predicate { $0.originRaw == scanned },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 4
        return descriptor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLocked {
                lockedRow
            } else if let latest = recent.first {
                Button { model.show(latest.scanResult) } label: {
                    PeekRow(record: latest)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens this scan")

                historyLink
            } else {
                emptyRow
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var lockedRow: some View {
        Button { model.openHistory() } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("History is locked")
                        .font(.headline)
                    Text("Pull up to unlock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var emptyRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 44, height: 44)
                .background(Palette.accent.opacity(0.16), in: .rect(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Point at any code")
                    .font(.headline)
                Text("Your scans will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// Condensed tiles of the scans before the latest, the total, and a chevron that says "pull up".
    private var historyLink: some View {
        let count = (try? modelContext.fetchCount(FetchDescriptor<ScanRecord>())) ?? 0
        let earlierKinds = recent.dropFirst().map(\.kind).uniqued()

        return Button { model.openHistory() } label: {
            HStack(spacing: 8) {
                HStack(spacing: -6) {
                    ForEach(earlierKinds, id: \.self) { kind in
                        KindTile(kind: kind, size: 22)
                            .background(Color(.systemBackground), in: .rect(cornerRadius: 7, style: .continuous))
                    }
                }
                Text("^[\(count) scan](inflect: true) in History")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: Double(count)))
                Spacer(minLength: 0)
                Image(systemName: "chevron.up")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 28)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Open History, ^[\(count) scan](inflect: true)"))
    }
}

/// The latest scan: tile, title, where and when, and a shield when the link checked out.
private struct PeekRow: View {
    let record: ScanRecord

    var body: some View {
        HStack(spacing: 12) {
            KindTile(kind: record.kind)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.historyTitle)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if record.placeName != nil {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .accessibilityHidden(true)
                    }
                    Text(detail)
                        .lineLimit(1)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if record.isVerifiedSafe {
                Image(systemName: "checkmark.shield.fill")
                    .font(.body)
                    .foregroundStyle(Palette.safe)
                    .accessibilityLabel("Verified safe")
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        let time = HistoryBucket.stamp(for: record.createdAt)
        if let place = record.placeName { return "\(place) · \(time)" }
        if !record.subtitle.isEmpty { return "\(record.subtitle) · \(time)" }
        return time
    }
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

#if DEBUG
#Preview {
    HistoryPeek(isLocked: false)
        .frame(height: 132)
        .environment(AppModel())
        .modelContainer(HistorySamples.container)
}
#endif
