import SwiftUI

/// A scan the user is looking at.
struct ScanResult: Identifiable, Hashable {
    let id = UUID()
    var code: ScannedCode
    var payload: Payload
    var scannedAt: Date = .now
    var placeName: String?
}

/// App-wide navigation state. Home is the root; the scanner is a full-screen cover that zooms out of
/// Home's Scan lens and runs the camera only while it's up; results and the multi-scan review are
/// sheets over whichever is on top.
@Observable
final class AppModel {
    /// Content of the sheet over Home or over the scanner.
    enum Sheet: Identifiable, Hashable {
        case result(ScanResult)
        case multiReview

        var id: String {
            switch self {
            case .result(let result): result.id.uuidString
            case .multiReview: "multiReview"
            }
        }
    }

    enum Modal: Identifiable, Hashable {
        /// The creator, optionally opened straight onto a screen (a Wi-Fi form, a code's studio).
        case create(CreateRoute? = nil)
        case settings

        var id: String {
            switch self {
            case .create: "create"
            case .settings: "settings"
            }
        }
    }

    /// Screens pushed on Home's navigation stack.
    enum Route: Hashable {
        case history
    }

    var path: [Route] = []
    var sheet: Sheet?
    var modal: Modal?
    /// A code shown full screen for someone else to scan.
    var codeOnDisplay: ShowCodeItem?

    /// The scanner cover is up (or zooming in or out of the Scan lens).
    private(set) var isScannerPresented = false
    /// Bumped each time the scanner has closed back into the Scan lens.
    private(set) var scannerCloseCount = 0

    /// One camera for every opening of the scanner: the session stays configured between them, so
    /// the feed is up almost at once instead of after a fresh setup each time.
    let camera = ScannerCamera()

    /// Codes collected in the current multi-scan session, newest last.
    var multiScanCodes: [ScanResult] = []
    var isMultiScanActive = false

    /// Shown once the scanner has gone, so two presentations never race.
    private var pendingModal: Modal?

    static let resultDetent = PresentationDetent.fraction(0.62)
    /// Time for a sheet or cover to finish leaving before the scanner presents over the root.
    static let presentationHandoff: Duration = .milliseconds(450)

    // MARK: Scanner

    /// Opens the camera. `multi` nil keeps the "Start in Multi-scan" preference.
    func openScanner(multi: Bool? = nil) {
        isMultiScanActive = multi ?? Pref.bool(Pref.multiScan, default: Pref.Default.multiScan)
        if isScannerPresented {
            sheet = nil
            return
        }
        let wasCovered = modal != nil || sheet != nil || codeOnDisplay != nil
        modal = nil
        sheet = nil
        codeOnDisplay = nil
        guard wasCovered else { return presentScanner() }
        Task {
            try? await Task.sleep(for: Self.presentationHandoff)
            presentScanner()
        }
    }

    /// Finger down on the Scan lens: the camera starts now, so the feed is live by the time the lens
    /// has zoomed open (a tap's action follows on finger up).
    func beginPeek() {
        guard !isScannerPresented, sheet == nil, modal == nil, codeOnDisplay == nil, path.isEmpty else { return }
        camera.setActive(true)
    }

    /// Finger up (or slid off) the Scan lens. If no tap opened the scanner, the camera goes back off.
    func endPeek() {
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            if !isScannerPresented { camera.setActive(false) }
        }
    }

    private func presentScanner() {
        LensHaptics.shared.open()
        isScannerPresented = true
    }

    /// Back to Home: the camera zooms back into the Scan lens. A sheet over it goes first, so the two
    /// presentations don't leave together.
    func closeScanner() {
        guard isScannerPresented else { return }
        isMultiScanActive = false
        multiScanCodes.removeAll()
        LensHaptics.shared.close()
        guard sheet != nil else {
            isScannerPresented = false
            return
        }
        sheet = nil
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            isScannerPresented = false
        }
    }

    /// The cover has gone (closed with its button, by itself, or swiped away).
    func scannerDidClose() {
        isScannerPresented = false
        scannerCloseCount += 1
        LensHaptics.shared.settle()
        if let pendingModal {
            self.pendingModal = nil
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                modal = pendingModal
            }
        }
    }

    // MARK: Results

    func show(_ result: ScanResult) {
        sheet = .result(result)
    }

    /// The result's close button: done with this code, back to Home.
    func dismissResult() {
        if isScannerPresented { closeScanner() } else { sheet = nil }
    }

    /// Puts the camera back, ready for the next code.
    func scanAnother() {
        if isScannerPresented {
            sheet = nil
        } else {
            openScanner(multi: false)
        }
    }

    func openHistory() {
        if isScannerPresented { closeScanner() } else { sheet = nil }
        path = [.history]
    }

    func openCreate(_ route: CreateRoute? = nil) {
        present(.create(route))
    }

    func openSettings() {
        present(.settings)
    }

    private func present(_ modal: Modal) {
        codeOnDisplay = nil
        if isScannerPresented {
            pendingModal = modal
            closeScanner()
        } else {
            sheet = nil
            self.modal = modal
        }
    }

    // MARK: Links

    /// `lunet://scan`, `lunet://scan?mode=multi`, `lunet://create`, `lunet://history`, `lunet://settings`
    /// (`ojito://`, `lens://` and `scanner://` route the same way).
    func handle(url: URL) {
        guard let link = LensDeepLink(url: url) else { return }
        route(to: link)
    }

    func route(to link: LensDeepLink) {
        switch link {
        case .scan: openScanner(multi: false)
        case .multiScan: openScanner(multi: true)
        case .create: openCreate()
        case .settings: openSettings()
        case .history:
            modal = nil
            codeOnDisplay = nil
            openHistory()
        }
    }
}
