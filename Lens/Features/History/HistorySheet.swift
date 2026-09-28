import StoreKit
import SwiftData
import SwiftUI

/// Content of the persistent sheet on Home: the latest scan at the peek detent, full History when pulled up.
struct HistorySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @AppStorage(Pref.requireFaceID) private var requireFaceID = Pref.Default.requireFaceID
    @AppStorage(Pref.successfulScans) private var successfulScans = 0
    @AppStorage(Pref.lastReviewPromptScans) private var lastReviewPromptScans = 0

    private let lock = HistoryLock.shared

    var body: some View {
        let isLocked = requireFaceID && !lock.isUnlocked

        Group {
            if model.detent == AppModel.peekDetent {
                HistoryPeek(isLocked: isLocked)
                    .transition(.opacity)
            } else {
                HistoryBrowser(isLocked: isLocked)
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.25), value: model.detent == AppModel.peekDetent)
        .task { LegacyImporter.runIfNeeded(into: modelContext) }
        .onAppear(perform: promptForReviewIfDue)
        .onDisappear { ReviewPrompter.leftHomeForResult = true }
    }

    /// Asks for a rating right after the user comes back from a result at a scan milestone.
    private func promptForReviewIfDue() {
        guard ReviewPrompter.leftHomeForResult else { return }
        ReviewPrompter.leftHomeForResult = false
        guard !model.isMultiScanActive,
              let milestone = ReviewPrompter.milestone(scans: successfulScans, lastPrompted: lastReviewPromptScans)
        else { return }
        lastReviewPromptScans = milestone
        Task {
            try? await Task.sleep(for: .seconds(0.8))
            requestReview()
        }
    }
}

#if DEBUG
#Preview("Peek") {
    Color.black
        .sheet(isPresented: .constant(true)) {
            HistorySheet()
                .presentationDetents([AppModel.peekDetent])
        }
        .environment(AppModel())
        .modelContainer(HistorySamples.container)
}

#Preview("Large") {
    let model = AppModel()
    model.detent = .large
    return Color.black
        .sheet(isPresented: .constant(true)) {
            HistorySheet()
                .presentationDetents([.large])
        }
        .environment(model)
        .modelContainer(HistorySamples.container)
}
#endif
