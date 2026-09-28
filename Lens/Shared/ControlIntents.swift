import AppIntents
import Foundation

// Actions behind the Control Center / Lock Screen / Action button controls. They live in both
// targets: the control runs them, and the system opens the app at the returned link.

@available(iOS 18.0, *)
struct OpenScannerControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan Code"
    static let description = IntentDescription("Opens the Lunet camera, ready to scan.")
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(LensDeepLink.scan.url))
    }
}

@available(iOS 18.0, *)
struct OpenMultiScanControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Multi-scan"
    static let description = IntentDescription("Opens the Lunet camera to collect several codes in a row.")
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(LensDeepLink.multiScan.url))
    }
}
