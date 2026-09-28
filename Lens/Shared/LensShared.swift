import Foundation

// Compiled into the app and the widget extension.
nonisolated enum LensShared {
    static let appGroup = "group.com.rvp97.scanner"
    static let scanURL = URL(string: "lens://scan")!
    static let multiScanURL = URL(string: "lens://scan?mode=multi")!
    static let createURL = URL(string: "lens://create")!
    static let historyURL = URL(string: "lens://history")!
    /// URL schemes the app answers to, all routed identically: `lunet://` is the public
    /// name; `ojito://`, `lens://` and `scanner://` stay for widgets, shortcuts and codes already out there.
    static let schemes: Set<String> = ["lunet", "ojito", "lens", "scanner"]
}

/// Every place outside the app (controls, widgets, Live Activity, Shortcuts) that opens Lens
/// goes through one of these links; `AppModel.handle(url:)` routes them.
nonisolated enum LensDeepLink: Hashable, Sendable {
    case scan
    case multiScan
    case create
    case history
    case settings

    var url: URL {
        switch self {
        case .scan: LensShared.scanURL
        case .multiScan: LensShared.multiScanURL
        case .create: LensShared.createURL
        case .history: LensShared.historyURL
        case .settings: URL(string: "lens://settings")!
        }
    }

    init?(url: URL) {
        guard let scheme = url.scheme, LensShared.schemes.contains(scheme) else { return nil }
        switch url.host() {
        case "scan":
            let mode = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "mode" }?.value
            self = mode == "multi" ? .multiScan : .scan
        case "create": self = .create
        case "history": self = .history
        case "settings": self = .settings
        default: return nil
        }
    }
}
