import Foundation
import Testing
@testable import Lens

struct EverywhereDeepLinkTests {
    @Test(arguments: [LensDeepLink.scan, .multiScan, .create, .history, .settings])
    func linksRoundTrip(_ link: LensDeepLink) {
        #expect(LensDeepLink(url: link.url) == link)
    }

    @Test func legacySchemeStillWorks() throws {
        let url = try #require(URL(string: "scanner://scan?mode=multi"))
        #expect(LensDeepLink(url: url) == .multiScan)
    }

    @Test(arguments: ["lunet", "ojito", "lens", "scanner"])
    func everySchemeRoutesTheSame(_ scheme: String) throws {
        #expect(LensDeepLink(url: try #require(URL(string: "\(scheme)://create"))) == .create)
        #expect(LensDeepLink(url: try #require(URL(string: "\(scheme)://scan?mode=multi"))) == .multiScan)
    }

    @Test func appRoutesLunetScheme() throws {
        let model = AppModel()
        model.handle(url: try #require(URL(string: "lunet://scan?mode=multi")))
        #expect(model.isMultiScanActive)
    }

    @Test func appStillRoutesOjitoScheme() throws {
        let model = AppModel()
        model.handle(url: try #require(URL(string: "ojito://create")))
        #expect(model.modal == .create)
    }

    @Test func foreignURLsAreIgnored() throws {
        #expect(LensDeepLink(url: try #require(URL(string: "https://lens.app/scan"))) == nil)
        #expect(LensDeepLink(url: try #require(URL(string: "lens://unknown"))) == nil)
    }

    @Test func unknownModeFallsBackToSingleScan() throws {
        #expect(LensDeepLink(url: try #require(URL(string: "lens://scan?mode=burst"))) == .scan)
    }

    @Test func appRoutesMultiScanLink() {
        let model = AppModel()
        model.handle(url: LensDeepLink.multiScan.url)
        #expect(model.isMultiScanActive)
        model.handle(url: LensDeepLink.scan.url)
        #expect(!model.isMultiScanActive)
    }
}

struct EverywhereLiveActivityStateTests {
    @Test func kindsAreNewestFirstWithoutRepeats() {
        let state = MultiScanAttributes.ContentState.make(
            count: 4,
            kinds: ["link", "wifi", "link", "product"],
            latest: "Fine-liner Pen"
        )
        #expect(state.kinds == ["product", "link", "wifi"])
        #expect(state.count == 4)
    }

    @Test func kindsAreCapped() {
        let state = MultiScanAttributes.ContentState.make(
            count: 6,
            kinds: ["text", "event", "contact", "travel", "product", "wifi"],
            latest: "Atlas Guest"
        )
        #expect(state.kinds == ["wifi", "product", "travel", "contact"])
    }
}

struct EverywhereShortcutTests {
    @Test func controlsNeedIOS18() {
        let shortcuts = EverywhereShortcut.available(isPhone: true, supportsControls: false)
        #expect(!shortcuts.contains(.controlCenter))
        #expect(shortcuts.contains(.lockScreen))
    }

    @Test func iPadHasNoActionButton() {
        let shortcuts = EverywhereShortcut.available(isPhone: false, supportsControls: true)
        #expect(shortcuts == [.controlCenter, .lockScreen])
    }

    @Test func everyShortcutHasAGuide() {
        for shortcut in EverywhereShortcut.allCases {
            #expect(shortcut.steps.count == 3)
        }
    }
}
