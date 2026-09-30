import SwiftUI

/// Home at the root with History pushed on its stack. The scanner is a full-screen cover opened
/// from the Scan lens; results, Create and Settings come up as sheets; a code shown to someone else
/// takes the whole screen.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Pref.onboardingDone) private var onboardingDone = false
    @Environment(\.modelContext) private var modelContext

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
        .tint(Palette.accent)
        // Home falls back as the camera opens out of the Scan lens.
        // (A dim, not a blur: blurring all of Home every frame makes the opening stutter on a phone.)
        .scaleEffect(model.isScannerRevealed ? 0.92 : 1, anchor: UnitPoint(x: 0.5, y: 0.8))
        .overlay {
            Color.black
                .opacity(model.isScannerRevealed ? 0.3 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .sheet(item: homeSheet) { SheetContent(sheet: $0) }
        .sheet(item: $model.modal) { modal in
            switch modal {
            case .create(let route): CreateView(route: route).pageSizedSheet()
            case .settings: SettingsView().pageSizedSheet()
            }
        }
        .fullScreenCover(item: $model.codeOnDisplay) { ShowCodeView(item: $0) }
        .fullScreenCover(isPresented: scannerBinding) { ScannerCover() }
        .fullScreenCover(isPresented: .constant(!onboardingDone)) {
            OnboardingFlow()
        }
        .onAppear(perform: openToCameraIfWanted)
#if DEBUG
        .task { QAHarness.apply(model: model, context: modelContext) }
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
        Binding(get: { model.isScannerPresented }, set: { if !$0 { model.scannerDidClose() } })
    }
}
