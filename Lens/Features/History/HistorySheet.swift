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

    /// Sheet height above which the full History replaces the peek row.
    private static let expandedThreshold: CGFloat = 260

    var body: some View {
        let isLocked = requireFaceID && !lock.isUnlocked

        // Both layouts stay mounted and cross-fade on the sheet's *measured* height. Swapping the
        // view tree on `model.detent` made UIKit re-apply detents mid-drag and snap the sheet back.
        GeometryReader { proxy in
            let expanded = proxy.size.height > Self.expandedThreshold
            ZStack(alignment: .top) {
                HistoryBrowser(isLocked: isLocked)
                    .opacity(expanded ? 1 : 0)
                    .allowsHitTesting(expanded)
                    .accessibilityHidden(!expanded)
                HistoryPeek(isLocked: isLocked)
                    .opacity(expanded ? 0 : 1)
                    .allowsHitTesting(!expanded)
                    .accessibilityHidden(expanded)
            }
            .animation(.smooth(duration: 0.2), value: expanded)
        }
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
