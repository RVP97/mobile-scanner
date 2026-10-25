import SwiftUI

/// Home at the root with History pushed on its stack. The scanner is a full-screen cover opened
/// from the Scan lens; results, Create and Settings come up as sheets; a code shown to someone else
/// takes the whole screen.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Pref.onboardingDone) private var onboardingDone = false
    @Environment(\.modelContext) private var modelContext
    /// Home's code cards grow into the full-screen code, and its lens into the camera, through this.
    @Namespace private var codeZoom

    var body: some View {
        @Bindable var model = model

        NavigationStack(path: $model.path) {
            HomeView()
                .navigationDestination(for: AppModel.Route.self) { route in
                    switch route {
                    case .history: HistoryBrowser()
                    }
                }
        }
        .environment(\.codeZoomNamespace, codeZoom)
        .tint(Palette.accent)
        .sheet(item: homeSheet) { SheetContent(sheet: $0) }
        .sheet(item: $model.modal) { modal in
            switch modal {
            case .create(let route): CreateView(route: route).pageSizedSheet()
            case .settings: SettingsView().pageSizedSheet()
            }
        }
        .fullScreenCover(item: $model.codeOnDisplay) { item in
            ShowCodeView(item: item)
                .codeZoomDestination(id: item.zoomSource, in: codeZoom)
        }
        .fullScreenCover(isPresented: scannerBinding, onDismiss: model.scannerDidClose) {
            // The Scan lens zooms open into the camera, and the camera back into the lens.
            ScannerCover()
                .codeZoomDestination(id: ScannerZoom.lens, in: codeZoom)
        }
        .fullScreenCover(isPresented: .constant(!onboardingDone)) {
            OnboardingFlow()
        }
        .onAppear(perform: openToCameraIfWanted)
#if DEBUG
        .task { QAHarness.apply(model: model, context: modelContext) }
        #if DEBUG
        .task { PerfWatchdog.startIfRequested() }
        #endif
#endif
    }

    /// "Open to camera": every launch starts in the scanner, the way Lunet used to.
    private func openToCameraIfWanted() {
#if DEBUG
        if QAHarness.isActive { return }
#endif
        if onboardingDone, Pref.bool(Pref.openToCamera, default: Pref.Default.openToCamera) {
            model.openScanner()
        }
    }

    /// Results over Home. Over the camera, the scanner presents its own.
    private var homeSheet: Binding<AppModel.Sheet?> {
        Binding(
            get: { model.isScannerPresented ? nil : model.sheet },
            set: { if !model.isScannerPresented { model.sheet = $0 } }
        )
    }

    private var scannerBinding: Binding<Bool> {
        // Swiped away: the same as Close.
        Binding(get: { model.isScannerPresented }, set: { if !$0 { model.closeScanner() } })
    }
}
