import AppIntents
import UIKit

// Shortcuts and Siri actions. The ones that open the app hand a deep link to the app's own
// URL handler, so they land exactly where a widget or control would.

struct ScanCodeIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan Code"
    static let description = IntentDescription("Opens Lens with the camera ready to scan.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await LensLinkOpener.open(.scan)
        return .result()
    }
}

struct StartMultiScanIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Multi-scan"
    static let description = IntentDescription("Opens Lens to collect several codes in a row.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await LensLinkOpener.open(.multiScan)
        return .result()
    }
}

struct CreateCodeIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Code"
    static let description = IntentDescription("Opens the Lens code creator.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await LensLinkOpener.open(.create)
        return .result()
    }
}

/// Reads a code from an image without opening the app. Handy in Shortcuts, e.g. after
/// "Take Screenshot" or "Select Photos".
struct ScanImageIntent: AppIntent {
    static let title: LocalizedStringResource = "Read Code in Image"
    static let description = IntentDescription("Finds a QR code or barcode in an image and returns what it says.")

    @Parameter(title: "Image", supportedTypeIdentifiers: ["public.image"])
    var image: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("Read the code in \(\.$image)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let codes = try await BarcodeImageReader.codes(in: image.data)
        guard let first = codes.first else { throw ScanImageError.noCode }
        return .result(value: first.raw, dialog: IntentDialog(stringLiteral: first.raw))
    }
}

nonisolated enum ScanImageError: Error, CustomLocalizedStringResourceConvertible {
    case noCode
    case unreadableImage

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noCode: "No QR code or barcode found in this image."
        case .unreadableImage: "This image couldn’t be opened."
        }
    }
}

/// Opens one of Lens's own links from inside the app, which routes it through `onOpenURL`.
enum LensLinkOpener {
    static func open(_ link: LensDeepLink) async {
        await UIApplication.shared.open(link.url)
    }
}

struct LensShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanCodeIntent(),
            phrases: [
                "Scan a code with \(.applicationName)",
                "Scan with \(.applicationName)",
                "Open the \(.applicationName) camera",
            ],
            shortTitle: "Scan Code",
            systemImageName: "qrcode.viewfinder"
        )
        AppShortcut(
            intent: StartMultiScanIntent(),
            phrases: [
                "Scan several codes with \(.applicationName)",
                "Start a multi-scan in \(.applicationName)",
            ],
            shortTitle: "Multi-scan",
            systemImageName: "square.stack.3d.up"
        )
        AppShortcut(
            intent: ScanImageIntent(),
            phrases: [
                "Read a code in an image with \(.applicationName)",
            ],
            shortTitle: "Read Code in Image",
            systemImageName: "photo.on.rectangle"
        )
        AppShortcut(
            intent: CreateCodeIntent(),
            phrases: [
                "Create a code with \(.applicationName)",
                "Make a QR code with \(.applicationName)",
            ],
            shortTitle: "Create Code",
            systemImageName: "qrcode"
        )
    }
}
