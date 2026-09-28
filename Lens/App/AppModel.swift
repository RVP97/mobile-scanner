import SwiftUI

/// A scan the user is looking at.
struct ScanResult: Identifiable, Hashable {
    let id = UUID()
    var code: ScannedCode
    var payload: Payload
    var scannedAt: Date = .now
    var placeName: String?
}

/// App-wide navigation state. The camera is always underneath; one persistent sheet
/// (Maps-style) shows the latest scan, History, or a result.
@Observable
final class AppModel {
    enum SheetContent: Hashable {
        case home
        case result(ScanResult)
        case multiReview
    }

    enum Modal: String, Identifiable {
        case create, settings
        var id: String { rawValue }
    }

    var sheetContent: SheetContent = .home
    var detent: PresentationDetent = AppModel.peekDetent
    var modal: Modal?

    /// Codes collected in the current multi-scan session, newest last.
    var multiScanCodes: [ScanResult] = []
    var isMultiScanActive = false

    /// Pauses the camera pipeline (onboarding, background, modal over camera).
    var cameraPaused = false

    static let peekDetent = PresentationDetent.height(132)
    static let resultDetent = PresentationDetent.fraction(0.62)

    // MARK: Actions

    func show(_ result: ScanResult) {
        withAnimation(.smooth(duration: 0.35)) {
            sheetContent = .result(result)
            detent = Self.resultDetent
        }
    }

    func dismissResult() {
        withAnimation(.smooth(duration: 0.3)) {
            sheetContent = .home
            detent = Self.peekDetent
        }
    }

    func openHistory() {
        withAnimation(.smooth) {
            sheetContent = .home
            detent = .large
        }
    }

    /// `lunet://scan`, `lunet://scan?mode=multi`, `lunet://create`, `lunet://history`, `lunet://settings`
    /// (`ojito://`, `lens://` and `scanner://` route the same way).
    func handle(url: URL) {
        guard let scheme = url.scheme, LensShared.schemes.contains(scheme) else { return }
        modal = nil
        switch url.host() {
        case "create": modal = .create
        case "settings": modal = .settings
        case "history": openHistory()
        case "scan":
            let multi = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "mode" }?.value == "multi"
            isMultiScanActive = multi
            dismissResult()
        default: break
        }
    }
}
