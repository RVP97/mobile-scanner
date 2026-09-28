import SwiftUI

/// Camera underneath, one persistent sheet on top. The sheet's content swaps between
/// the peek/History view and a result, so a scan feels like the code rising into a card.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Pref.onboardingDone) private var onboardingDone = false

    var body: some View {
        @Bindable var model = model

        ScannerScreen()
            .sheet(isPresented: .constant(onboardingDone)) {
                sheetContent
                    .presentationDetents(detents, selection: $model.detent)
                    .presentationBackgroundInteraction(.enabled(upThrough: interactiveDetent))
                    .presentationDragIndicator(.visible)
                    .modifier(CameraSheetSurface())
                    .interactiveDismissDisabled()
                    .sheet(item: $model.modal) { modal in
                        switch modal {
                        case .create: CreateView()
                        case .settings: SettingsView()
                        }
                    }
            }
            .fullScreenCover(isPresented: .constant(!onboardingDone)) {
                OnboardingFlow()
            }
    }

    @ViewBuilder
    private var sheetContent: some View {
        switch model.sheetContent {
        case .home:
            HistorySheet()
        case .result(let result):
            ResultView(result: result)
                .id(result.id)
        case .multiReview:
            MultiScanReview()
        }
    }

    /// The largest detent at which the camera stays live and tappable. Must be a member of
    /// `detents`, or UIKit silently ignores it and dims the camera.
    private var interactiveDetent: PresentationDetent {
        switch model.sheetContent {
        case .home: AppModel.peekDetent
        case .result: AppModel.resultDetent
        case .multiReview: .medium
        }
    }

    private var detents: Set<PresentationDetent> {
        switch model.sheetContent {
        case .home: [AppModel.peekDetent, .large]
        case .result: [AppModel.resultDetent, .large]
        case .multiReview: [.medium, .large]
        }
    }
}

/// Light glass over a dark camera reads as muddy grey, so in light mode the sheet gets a
/// solid surface. Dark mode keeps the system material (Liquid Glass on iOS 26).
private struct CameraSheetSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if colorScheme == .light {
            content.presentationBackground(Color(.systemBackground))
        } else {
            content
        }
    }
}
