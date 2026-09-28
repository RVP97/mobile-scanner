#if DEBUG
import SwiftData
import SwiftUI

/// Debug-only launch arguments that open any screen with realistic data, so every state can be
/// reviewed (and screenshotted) in both appearances without a camera:
///
///     xcrun simctl launch <udid> com.rvp97.scanner -qaAppearance dark -qaSeed YES -qaScreen result:wifi
///
/// `-qaScreen`: `home`, `history`, `create`, `settings`, `multi`, `result:<link|caution|danger|wifi|openwifi|
/// product|travel|contact|event|location|crypto|shipment|text|email|sms|phone>`.
/// `-qaOnboarding <welcome|answers|safety|camera|firstScan|everywhere>`. `-qaCodeCover YES` opens a result's
/// full-screen code. `-qaDetent large` opens the sheet expanded.
enum QAHarness {
    private static var arguments: UserDefaults { .standard }

    static var onboardingStep: OnboardingStep? {
        guard let name = arguments.string(forKey: "qaOnboarding") else { return nil }
        return OnboardingStep.allCases.first { "\($0)" == name }
    }

    /// Runs once at launch, before the first frame settles.
    static func apply(model: AppModel, context: ModelContext) {
        if let appearance = arguments.string(forKey: "qaAppearance") {
            UserDefaults.standard.set(appearance, forKey: Pref.appearance)
        }
        if onboardingStep != nil {
            UserDefaults.standard.set(false, forKey: Pref.onboardingDone)
            return
        }
        guard let screen = arguments.string(forKey: "qaScreen") else { return }
        UserDefaults.standard.set(true, forKey: Pref.onboardingDone)

        if arguments.bool(forKey: "qaSeed"),
           (try? context.fetchCount(FetchDescriptor<ScanRecord>())) == 0 {
            HistorySamples.records().forEach(context.insert)
        }

        switch screen {
        case "history": model.openHistory()
        case "create": model.modal = .create
        case "settings": model.modal = .settings
        case "multi":
            model.multiScanCodes = [.sampleLink, .sampleProduct, .sampleWiFi]
            model.isMultiScanActive = true
            model.sheetContent = .multiReview
            model.detent = .large
        default:
            if screen.hasPrefix("result:"), let result = sample(named: String(screen.dropFirst(7))) {
                model.show(result)
            }
        }
        if arguments.string(forKey: "qaDetent") == "large" {
            model.detent = .large
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
