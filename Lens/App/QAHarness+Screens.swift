#if DEBUG
import SwiftData
import SwiftUI

/// Deeper `-qaScreen` destinations for Create, Settings and History states:
///
///     -qaScreen studio            Wi-Fi QR in the studio (Dots tool)
///     -qaScreen studio:<tool>     dots | corners | color | logo | frame
///     -qaScreen studio -qaPreset lagoon -qaLogo YES -qaFrame card   a styled code
///     -qaScreen studio:barcode    an EAN-13 in the studio
///     -qaScreen create:<intent>   link | wifi | contact | text | email | sms | phone | event | location | product
///     -qaScreen create:formats    the Advanced format list
///     -qaScreen privacy           Settings › Privacy
///     -qaScreen everywhere        Settings › Scan from Anywhere
///     -qaScreen history:locked    History behind the lock, without the automatic passcode prompt
///                                 (launch-argument only: nothing is written to the real preferences)
///     -qaScreen restyle           the seeded Casa Chen Wi-Fi back in the studio (pass -qaSeed YES)
///
/// Add `-qaFill YES` to `create:<intent>` to open the form with realistic content, and
/// `-qaLargeSheet YES` to open a result sheet at the large detent.
extension QAHarness {
    /// The Create modal's initial navigation path.
    @MainActor static var createPath: [CreateRoute] = []
    /// Studio tool to open with, if any.
    @MainActor static var studioTool: StudioTool?
    /// Style to open the studio with, from `-qaPreset <id>`, `-qaLogo YES` and `-qaFrame <frame>`.
    @MainActor static var studioStyle: CodeStyle?
    /// The Settings modal's initial navigation path.
    @MainActor static var settingsPath: [SettingsRoute] = []

    /// Keeps the locked History screen visible instead of covering it with the system prompt.
    @MainActor static var suppressesAuthPrompt = false

    static var fillsForms: Bool { UserDefaults.standard.bool(forKey: "qaFill") }

    /// `-qaHistoryFilter <pinned|created|link|wifi|…>` and `-qaHistorySearch <text>` open History filtered.
    static var historyCriteria: HistoryCriteria {
        let defaults = UserDefaults.standard
        var criteria = HistoryCriteria()
        switch defaults.string(forKey: "qaHistoryFilter") {
        case "pinned": criteria.filter = .pinned
        case "created": criteria.filter = .created
        case let raw?: if let kind = CodeKind(rawValue: raw) { criteria.filter = .kind(kind) }
        case nil: break
        }
        criteria.search = defaults.string(forKey: "qaHistorySearch") ?? ""
        return criteria
    }

    /// `-qaLargeSheet YES` opens a result sheet at the large detent, so a whole result is in view.
    static var opensSheetsLarge: Bool { UserDefaults.standard.bool(forKey: "qaLargeSheet") }

    /// Handles the screens above. Returns false for names it doesn't know.
    @MainActor
    static func applyExtended(_ screen: String, model: AppModel, context: ModelContext) -> Bool {
        let parts = screen.split(separator: ":", maxSplits: 1).map(String.init)
        let argument = parts.count > 1 ? parts[1] : nil

        switch parts.first {
        case "studio":
            if argument == "barcode" {
                createPath = [.studio(sampleBarcode)]
            } else {
                createPath = [.studio(sampleWiFi)]
                studioTool = argument.flatMap(StudioTool.init(rawValue:))
                studioStyle = requestedStudioStyle
            }
            model.modal = .create()
        case "restyle":
            let created = ScanRecord.Origin.created.rawValue
            let records = (try? context.fetch(FetchDescriptor<ScanRecord>(predicate: #Predicate { $0.originRaw == created }))) ?? []
            guard let record = records.first(where: { $0.kind == .wifi }) else { return true }
            model.openCreate(.restyle(record))
        case "create":
            if argument == "formats" {
                createPath = [.formats]
            } else if let intent = argument.flatMap(CreateIntent.init(rawValue:)) {
                createPath = [.compose(intent)]
            }
            model.modal = .create()
        case "privacy":
            settingsPath = [.privacy]
            model.modal = .settings
        case "everywhere":
            settingsPath = [.scanAnywhere]
            model.modal = .settings
        case "history":
            if argument == "locked" {
                // The argument domain overrides the stored value for this launch only.
                UserDefaults.standard.setVolatileDomain([Pref.requireFaceID: true], forName: UserDefaults.argumentDomain)
                HistoryLock.shared.lock()
                suppressesAuthPrompt = true
            }
            model.path = [.history]
        default:
            return false
        }
        return true
    }

    private static var requestedStudioStyle: CodeStyle? {
        let defaults = UserDefaults.standard
        let preset = defaults.string(forKey: "qaPreset").flatMap { id in StylePreset.all.first { $0.id == id } }
        let frame = defaults.string(forKey: "qaFrame").flatMap(CodeStyle.Frame.init(rawValue:))
        let logo = defaults.bool(forKey: "qaLogo")
        guard preset != nil || frame != nil || logo else { return nil }
        var style = preset?.style ?? CodeStyle()
        if logo { style.logo = .kindGlyph }
        if let frame {
            style.frame = frame
            style.caption = sampleWiFi.caption
        }
        return style
    }

    /// Realistic content for a compose form when `-qaFill YES` is passed.
    static func fill(_ draft: CreateDraft) {
        guard fillsForms else { return }
        switch draft.intent {
        case .link: draft.link = "atlas-coffee.co/menu"
        case .wifi: draft.wifi = WiFiNetwork(ssid: "Casa Chen", password: "correct horse")
        case .contact:
            draft.contact.givenName = "Maya"
            draft.contact.familyName = "Chen"
            draft.contact.organization = "Studio Norte"
            draft.contactPhone = "+52 55 1234 5678"
            draft.contactEmail = "maya@studionorte.mx"
        case .text: draft.text = "Locker 214 — code 5591"
        case .email: draft.email.to = "hola@atlas-coffee.co"
        case .sms: draft.sms.number = "+52 55 1234 5678"
        case .phone: draft.phone = "+52 55 1234 5678"
        case .event: draft.event.title = "Studio Norte launch"
        case .location: draft.locationLabel = "Atlas Coffee"
        case .product: draft.product = "4006381333931"
        case nil: draft.advancedText = "SHIP-88213-XK"
        }
    }

    private static var sampleWiFi: CodeDocument {
        CodeDocument(
            raw: "WIFI:T:WPA;S:Casa Chen;P:correct horse;;",
            symbology: .qr,
            payload: .wifi(WiFiNetwork(ssid: "Casa Chen", password: "correct horse")),
            title: "Casa Chen",
            caption: "Scan to join Casa Chen"
        )
    }

    private static var sampleBarcode: CodeDocument {
        CodeDocument(
            raw: "4006381333931",
            symbology: .ean13,
            payload: .product(gtin: "4006381333931"),
            title: "4006381333931",
            caption: "Scan for product details"
        )
    }
}
#endif
