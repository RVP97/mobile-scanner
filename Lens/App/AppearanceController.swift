import UIKit

/// Applies the user's System / Light / Dark choice to every window, so sheets, covers and
/// alerts follow it too. SwiftUI's `preferredColorScheme` only reaches the presenting
/// hierarchy and doesn't reliably return to "System".
enum AppearanceController {
    static func apply(_ appearance: String) {
        let style: UIUserInterfaceStyle = switch appearance {
        case "light": .light
        case "dark": .dark
        default: .unspecified
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
