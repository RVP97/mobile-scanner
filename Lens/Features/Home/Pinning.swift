import SwiftData
import SwiftUI

/// Pinning keeps a scan under "Your codes" on Home.
enum Pinning {
    /// The saved row for a code, newest first.
    static func record(for raw: String, in context: ModelContext) -> ScanRecord? {
        var descriptor = FetchDescriptor<ScanRecord>(
            predicate: #Predicate { $0.raw == raw },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func isPinned(_ raw: String, in context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<ScanRecord>(predicate: #Predicate { $0.raw == raw && $0.isPinned })
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    /// Pins or unpins a result. Pinning is an explicit "keep this", so it saves the code even when
    /// History is off.
    static func setPinned(_ pinned: Bool, for result: ScanResult, in context: ModelContext) {
        if let record = record(for: result.code.raw, in: context) {
            record.isPinned = pinned
        } else if pinned {
            let record = ScanRecord(
                raw: result.code.raw,
                symbology: result.code.symbology,
                kind: result.payload.kind,
                title: result.payload.displayTitle,
                subtitle: result.payload.displaySubtitle,
                createdAt: result.scannedAt
            )
            record.isPinned = true
            record.placeName = result.placeName
            context.insert(record)
        }
        try? context.save()
    }
}

/// "Pin to Your Codes" / "Unpin" for a result, with a haptic and a symbol that swaps in place.
struct PinButton: View {
    var result: ScanResult

    @Environment(\.modelContext) private var modelContext
    @State private var isPinned = false

    var body: some View {
        Button {
            isPinned.toggle()
            Pinning.setPinned(isPinned, for: result, in: modelContext)
        } label: {
            Label(isPinned ? "Unpin" : "Pin to Your Codes", systemImage: isPinned ? "pin.slash" : "pin")
                .contentTransition(.symbolEffect(.replace))
        }
        .sensoryFeedback(.selection, trigger: isPinned)
        .onAppear { isPinned = Pinning.isPinned(result.code.raw, in: modelContext) }
    }
}
