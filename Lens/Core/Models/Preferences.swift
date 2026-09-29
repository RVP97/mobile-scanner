import Foundation

/// UserDefaults keys. Read with `@AppStorage(Pref.haptics) var haptics = Pref.Default.haptics`.
enum Pref {
    static let onboardingDone = "onboardingDone"
    static let haptics = "haptics"
    static let sound = "sound"
    static let scanAndGo = "scanAndGo"
    static let multiScan = "multiScan"
    /// Launch straight into the camera instead of Home.
    static let openToCamera = "openToCamera"
    static let autoCopy = "autoCopy"
    static let checkLinks = "checkLinks"
    static let deepLinkCheck = "deepLinkCheck"
    static let blockDangerous = "blockDangerous"
    static let saveHistory = "saveHistory"
    static let rememberPlace = "rememberPlace"
    static let requireFaceID = "requireFaceID"
    static let appearance = "appearance"          // "system" | "light" | "dark"
    static let successfulScans = "successfulScans"
    static let lastReviewPromptScans = "lastReviewPromptScans"

    enum Default {
        static let haptics = true
        static let sound = true
        static let scanAndGo = false
        static let multiScan = false
        static let openToCamera = false
        static let autoCopy = false
        static let checkLinks = true
        static let deepLinkCheck = true
        static let blockDangerous = true
        static let saveHistory = true
        static let rememberPlace = false
        static let requireFaceID = false
        static let appearance = "system"
    }

    static func bool(_ key: String, default value: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? value
    }
}
