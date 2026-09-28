import SwiftData
import SwiftUI

@main
struct LensApp: App {
    @State private var model = AppModel()
    @AppStorage(Pref.appearance) private var appearance = Pref.Default.appearance

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(colorScheme)
                .onOpenURL { model.handle(url: $0) }
        }
        .modelContainer(for: [ScanRecord.self, SavedStyle.self])
    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }
}
