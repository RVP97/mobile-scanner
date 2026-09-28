import CoreGraphics
import Foundation
import Testing
@testable import Lens

struct ScannerZoomTests {
    /// Triple camera: device factor 1 is the ultra-wide lens.
    private let triple = ZoomProfile(minimumDeviceFactor: 1, maximumDeviceFactor: 123, displayMultiplier: 0.5)
    private let wideOnly = ZoomProfile(minimumDeviceFactor: 1, maximumDeviceFactor: 16, displayMultiplier: 1)

    @Test func virtualDeviceOffersUltraWide() {
        #expect(triple.presets == [0.5, 1, 2])
        #expect(triple.deviceFactor(forDisplay: 1) == 2)
        #expect(triple.deviceFactor(forDisplay: 0.5) == 1)
        #expect(triple.displayZoom(forDevice: 4) == 2)
    }

    @Test func singleLensHasNoHalfZoom() {
        #expect(wideOnly.presets == [1, 2])
    }

    @Test func fixedLensShowsNoCapsule() {
        #expect(ZoomProfile.fixed.presets.isEmpty)
    }

    @Test func pinchIsClampedToTenTimes() {
        #expect(triple.clampedDisplay(40) == 10)
        #expect(triple.clampedDisplay(0.1) == 0.5)
        #expect(triple.deviceFactor(forDisplay: 40) == 20)
    }

    @Test func activePresetFollowsPinch() {
        #expect(triple.activePreset(for: 0.7) == 0.5)
        #expect(triple.activePreset(for: 1.4) == 1)
        #expect(triple.activePreset(for: 6) == 2)
        #expect(triple.activePreset(for: 0.98) == 1)
    }

    @Test func labelsMatchCameraStyle() {
        let decimal = Locale.current.decimalSeparator ?? "."
        #expect(ZoomProfile.label(for: 0.5) == "\(decimal)5")
        #expect(ZoomProfile.label(for: 1) == "1")
        #expect(ZoomProfile.label(for: 2.0) == "2")
        #expect(ZoomProfile.label(for: 1.43) == "1\(decimal)4")
    }

    @Test func legacyMultiplierFromSwitchOver() {
        #expect(ZoomProfile.legacyMultiplier(hasUltraWide: true, switchOverFactors: [2, 6]) == 0.5)
        #expect(ZoomProfile.legacyMultiplier(hasUltraWide: false, switchOverFactors: [3]) == 1)
        #expect(ZoomProfile.legacyMultiplier(hasUltraWide: true, switchOverFactors: []) == 1)
    }

    @Test func recommendedZoomForLongMinimumFocus() {
        // A 20 cm minimum focus distance on a ~70° lens needs roughly 1.5–2× to fill the frame
        // with a 2 cm code.
        let zoom = ZoomProfile.recommendedZoom(fieldOfView: 70, minimumFocusDistance: 200)
        #expect(zoom > 1.2 && zoom <= 2)
    }

    @Test func noZoomWhenLensFocusesCloseEnoughOrUnknown() {
        #expect(ZoomProfile.recommendedZoom(fieldOfView: 70, minimumFocusDistance: 40) == 1)
        #expect(ZoomProfile.recommendedZoom(fieldOfView: 70, minimumFocusDistance: -1) == 1)
    }
}
