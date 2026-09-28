import AudioToolbox
import Observation
import SwiftData
import SwiftUI

/// What happens once a code is read: feedback, saving, Scan & Go, the lock chip and the lift into the
/// result sheet, multi-scan collection, and codes imported from images.
@Observable
final class ScanCoordinator {
    enum Stage: Equatable {
        case searching
        /// Brackets hold on the code and the chip names it.
        case locked
        /// The code is lifting into the result sheet.
        case lifting
    }

    struct Lock: Equatable {
        var result: ScanResult
        var quad: Quad
        var codeImage: UIImage?
    }

    struct Toast: Equatable, Identifiable {
        let id = UUID()
        var message: LocalizedStringResource
        var symbol: String
    }

    /// Things only the view can supply.
    struct Context {
        var model: AppModel
        var modelContext: ModelContext
        var openURL: OpenURLAction
    }

    private(set) var stage: Stage = .searching
    private(set) var lock: Lock?
    private(set) var toast: Toast?
    /// Bumped on each lock (medium impact) and each multi-scan capture (light impact).
    private(set) var lockFeedback = 0
    private(set) var captureFeedback = 0

    let tracker = ScanTracker()
    @ObservationIgnored var reduceMotion = false
    @ObservationIgnored private var sequence: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    /// How long the chip names the code before it lifts.
    static let chipDwell: Duration = .milliseconds(350)
    static let liftDuration: Duration = .milliseconds(360)

    // MARK: Camera

    func process(_ reads: [CodeRead], context: Context) {
        guard stage == .searching else { return }
        let stable = tracker.ingest(reads)
        guard let first = stable.first else { return }

        if context.model.isMultiScanActive {
            stable.forEach { collect($0.scannedCode, context: context) }
        } else {
            lockOn(first, context: context)
        }
    }

    private func lockOn(_ read: CodeRead, context: Context) {
        let result = ScanResult(code: read.scannedCode, payload: PayloadParser.parse(read.raw, symbology: read.symbology))
        acknowledge(result, context: context)
        lockFeedback += 1

        let image = reduceMotion ? nil : CodeRenderer.image(raw: read.raw, symbology: read.symbology, dimension: 120)
        withAnimation(.snappy(duration: 0.2)) {
            lock = Lock(result: result, quad: read.quad, codeImage: image)
            stage = .locked
        }

        if let url = scanAndGoURL(for: result.payload) {
            context.openURL(url)
            sequence = Task {
                try? await Task.sleep(for: .milliseconds(700))
                finish()
            }
            return
        }

        sequence = Task {
            try? await Task.sleep(for: Self.chipDwell)
            guard !Task.isCancelled else { return }
            if reduceMotion {
                context.model.show(result)
                finish()
                return
            }
            withAnimation(.smooth(duration: 0.15)) { stage = .lifting }
            context.model.show(result)
            try? await Task.sleep(for: Self.liftDuration)
            finish()
        }
    }

    private func finish() {
        withAnimation(.smooth(duration: 0.2)) {
            stage = .searching
            lock = nil
        }
    }

    /// Links open straight away with Scan & Go, unless the quick check has any doubt.
    private func scanAndGoURL(for payload: Payload) -> URL? {
        guard Pref.bool(Pref.scanAndGo, default: Pref.Default.scanAndGo), case .link(let url) = payload else { return nil }
        let level = SafetyAnalyzer.quickCheck(url).level
        return level == .danger || level == .caution ? nil : url
    }

    // MARK: Multi-scan

    private func collect(_ code: ScannedCode, context: Context) {
        let model = context.model
        guard !model.multiScanCodes.contains(where: { $0.code.raw == code.raw }) else { return }
        let result = ScanResult(code: code, payload: PayloadParser.parse(code.raw, symbology: code.symbology))
        acknowledge(result, context: context)
        captureFeedback += 1
        withAnimation(.bouncy(duration: 0.4)) {
            model.multiScanCodes.append(result)
        }
        MultiScanActivity.update(
            count: model.multiScanCodes.count,
            kinds: model.multiScanCodes.map(\.payload.kind),
            latest: result.payload.displayTitle
        )
    }

    // MARK: Images

    /// Handles image data from Photos, drag and drop or the pasteboard.
    func importImage(_ data: Data, context: Context) async {
        let codes: [ScannedCode]
        do {
            codes = try await ImageCodeReader.codes(in: data)
        } catch {
            show(Toast(message: "Couldn’t open that image", symbol: "photo.badge.exclamationmark"))
            return
        }
        present(imported: codes, context: context)
    }

    func present(imported codes: [ScannedCode], context: Context) {
        let model = context.model
        switch codes.count {
        case 0:
            show(Toast(message: "No code found in that image", symbol: "viewfinder"))
        case 1:
            let result = ScanResult(code: codes[0], payload: PayloadParser.parse(codes[0].raw, symbology: codes[0].symbology))
            tracker.suppress(result.code.raw)
            acknowledge(result, context: context)
            model.show(result)
        default:
            if !model.isMultiScanActive { model.multiScanCodes.removeAll() }
            for code in codes where !model.multiScanCodes.contains(where: { $0.code.raw == code.raw }) {
                let result = ScanResult(code: code, payload: PayloadParser.parse(code.raw, symbology: code.symbology))
                tracker.suppress(code.raw)
                RecordWriter.save(result, in: context.modelContext)
                model.multiScanCodes.append(result)
            }
            captureFeedback += 1
            withAnimation(.smooth(duration: 0.35)) {
                model.sheetContent = .multiReview
                model.detent = .large
            }
        }
    }

    // MARK: Feedback

    private func acknowledge(_ result: ScanResult, context: Context) {
        if Pref.bool(Pref.sound, default: Pref.Default.sound) {
            AudioServicesPlaySystemSound(Self.lockSound)
        }
        if Pref.bool(Pref.autoCopy, default: Pref.Default.autoCopy) {
            UIPasteboard.general.string = result.code.raw
        }
        RecordWriter.save(result, in: context.modelContext)

        let title = String(localized: result.payload.kind.title)
        AccessibilityNotification.Announcement("\(title), \(result.payload.displayTitle)").post()
    }

    private func show(_ toast: Toast) {
        withAnimation(.snappy) { self.toast = toast }
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth) { self.toast = nil }
        }
    }

    /// A short, quiet tick ("Tink"). System sounds respect the ring/silent switch.
    private static let lockSound: SystemSoundID = 1057
}
