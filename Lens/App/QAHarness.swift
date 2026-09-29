#if DEBUG
import PassKit
import SwiftData
import SwiftUI

/// Debug-only launch arguments that open any screen with realistic data, so every state can be
/// reviewed (and screenshotted) in both appearances without a camera:
///
///     xcrun simctl launch <udid> com.rvp97.scanner -qaAppearance dark -qaSeed YES -qaScreen show:wifi
///
/// `-qaScreen`:
/// - `home` (add `-qaSeed YES` for sample codes and scans), `home:empty` (wipes the store first)
/// - `scan`, `scan:multi`, `scan:result:<name>` (a result over the camera), `multi` (the multi-scan review)
/// - `show:<wifi|travel|contact|link>` a code full screen, `result:<name>` a result over Home, where
///   `<name>` is `link|caution|danger|wifi|openwifi|product|travel|contact|event|location|crypto|shipment|
///   text|email|sms|phone`
/// - `history`, `create`, `settings`, and the deeper screens in `QAHarness+Screens.swift`
///
/// `-qaOnboarding <welcome|answers|safety|camera|firstScan|everywhere>`. `-qaCodeCover YES` opens a result's
/// full-screen code. `-qaWelcomeTime 0.6` freezes the Welcome animation at that moment.
enum QAHarness {
    private static var arguments: UserDefaults { .standard }

    /// A QA launch: don't apply launch-time preferences like "Open to camera".
    static var isActive: Bool {
        arguments.string(forKey: "qaScreen") != nil || arguments.string(forKey: "qaOnboarding") != nil
    }

    static var welcomeTime: Double? {
        arguments.object(forKey: "qaWelcomeTime") == nil ? nil : arguments.double(forKey: "qaWelcomeTime")
    }

    static var onboardingStep: OnboardingStep? {
        guard let name = arguments.string(forKey: "qaOnboarding") else { return nil }
        return OnboardingStep.allCases.first { "\($0)" == name }
    }

    /// Runs once at launch, before the first frame settles.
    static func apply(model: AppModel, context: ModelContext) {
        if arguments.bool(forKey: "qaWalletTest") { runWalletTest() }
        if let appearance = arguments.string(forKey: "qaAppearance") {
            UserDefaults.standard.set(appearance, forKey: Pref.appearance)
        }
        if onboardingStep != nil {
            UserDefaults.standard.set(false, forKey: Pref.onboardingDone)
            return
        }
        guard let screen = arguments.string(forKey: "qaScreen") else { return }
        UserDefaults.standard.set(true, forKey: Pref.onboardingDone)

        if screen.hasSuffix(":empty") || arguments.bool(forKey: "qaSeed") {
            try? context.delete(model: ScanRecord.self)
        }
        if arguments.bool(forKey: "qaSeed") && !screen.hasSuffix(":empty") {
            HistorySamples.records().forEach(context.insert)
        }
        try? context.save()

        switch screen {
        case "home", "home:empty": break
        case "history", "history:empty": model.path = [.history]
        case "create": model.modal = .create()
        case "settings": model.modal = .settings
        case "scan": model.openScanner(multi: false)
        case "scan:multi":
            model.openScanner(multi: true)
            model.multiScanCodes = [.sampleLink, .sampleProduct]
        case "multi":
            model.openScanner(multi: true)
            model.multiScanCodes = [.sampleLink, .sampleProduct, .sampleWiFi]
            model.sheet = .multiReview
        default:
            if applyExtended(screen, model: model, context: context) { return }
            if screen.hasPrefix("scan:result:"), let result = sample(named: String(screen.dropFirst(12))) {
                model.openScanner(multi: false)
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    model.show(result)
                }
            } else if screen.hasPrefix("result:"), let result = sample(named: String(screen.dropFirst(7))) {
                model.show(result)
            } else if screen.hasPrefix("show:") {
                model.codeOnDisplay = showItem(named: String(screen.dropFirst(5)), context: context)
            }
        }
    }

    /// A seeded code for `show:<name>`, as Home would open it.
    private static func showItem(named name: String, context: ModelContext) -> ShowCodeItem? {
        let kind: CodeKind? = switch name {
        case "wifi": .wifi
        case "travel": .travel
        case "contact": .contact
        case "link": .link
        default: nil
        }
        guard let kind else { return nil }
        let records = (try? context.fetch(CodeShelf.descriptor)) ?? []
        if let record = records.first(where: { $0.kind == kind && $0.origin == .created }) ?? records.first(where: { $0.kind == kind }) {
            return ShowCodeItem(record: record)
        }
        return sample(named: name).map(ShowCodeItem.init(result:))
    }

    /// `-qaWalletTest YES`: creates a Wallet pass for the sample boarding pass on launch and prints
    /// each step (`[Wallet] …`) to the console, for diagnosing the signing round trip on a device.
    private static func runWalletTest() {
        let sample = ScanResult.sampleTravel
        guard case .travel(let pass) = sample.payload else { return print("[Wallet] sample isn't a boarding pass") }
        Task {
            print("[Wallet] test start; App Attest supported: \(WalletClient.isSupported)")
            do {
                let data = try await WalletClient.shared.makeBoardingPass(pass, raw: sample.code.raw, symbology: sample.code.symbology)
                print("[Wallet] received \(data.count) bytes")
                let pkpass = try PKPass(data: data)
                print("[Wallet] VALID pass \(pkpass.serialNumber)")
            } catch {
                print("[Wallet] FAILED: \(error)")
            }
        }
    }

    private static func sample(named name: String) -> ScanResult? {
        switch name {
        case "link": .sampleLink
        case "danger": .sampleDanger
        case "caution": .sampleCaution
        case "email": .sample("mailto:hola@atlas-coffee.co?subject=Catering%20for%2040&body=Hi!%20Could%20you%20cater%20our%20offsite%20on%20Friday%3F")
        case "sms": .sample("SMSTO:+525512345678:Table 4 is ready")
        case "phone": .sample("tel:+525512345678")
        case "openwifi": .sample("WIFI:T:nopass;S:Atlas Patio;;")
        case "wifi": .sampleWiFi
        case "product": .sampleProduct
        case "travel": .sampleTravel
        case "contact": .sampleContact
        case "event": .sampleEvent
        case "location": .sampleLocation
        case "crypto": .sampleCrypto
        case "shipment": .sampleShipment
        case "text": .sampleText
        default: nil
        }
    }
}
#endif
