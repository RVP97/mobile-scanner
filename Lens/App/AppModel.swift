import SwiftUI

/// A scan the user is looking at.
struct ScanResult: Identifiable, Hashable {
    let id = UUID()
    var code: ScannedCode
    var payload: Payload
    var scannedAt: Date = .now
    var placeName: String?
}

/// App-wide navigation state. Home is the root; the scanner is a full-screen cover that runs the
/// camera only while it's up; results and the multi-scan review are sheets over whichever is on top.
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

    /// The scanner cover is in the hierarchy (opening, open or closing).
    private(set) var isScannerPresented = false
    /// The scanner is animating closed; `scannerDidClose()` removes it.
    private(set) var isScannerClosing = false
    /// Where Home's Scan lens sits on screen (global coordinates), so the viewfinder opens out of it.
    var lensFrame: CGRect?

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
            isScannerClosing = false
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

    private func presentScanner() {
        // The viewfinder draws its own opening, so the cover appears without the system slide.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { isScannerPresented = true }
    }

    /// Back to Home. The cover animates closed, then calls `scannerDidClose()`.
    func closeScanner() {
        guard isScannerPresented, !isScannerClosing else { return }
        sheet = nil
        isScannerClosing = true
        isMultiScanActive = false
        multiScanCodes.removeAll()
    }

    func scannerDidClose() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isScannerPresented = false
            isScannerClosing = false
        }
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
        sheet = nil
        closeScanner()
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
        sheet = nil
        closeScanner()
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
