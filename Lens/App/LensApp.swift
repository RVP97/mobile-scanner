import SwiftData
import SwiftUI

@main
struct LensApp: App {
    @State private var model = AppModel()
    @AppStorage(Pref.appearance) private var appearance = Pref.Default.appearance
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onOpenURL { model.handle(url: $0) }
                .onAppear { AppearanceController.apply(appearance) }
                .onChange(of: appearance) { _, value in AppearanceController.apply(value) }
                .onChange(of: scenePhase) { _, phase in
                    // New windows (a second iPad scene, a restored scene) pick up the choice too.
                    if phase == .active { AppearanceController.apply(appearance) }
                }
        }
        .modelContainer(for: [ScanRecord.self, SavedStyle.self])
    }
}
