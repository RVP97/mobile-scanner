import CoreGraphics
import Foundation

/// Maps between the zoom numbers people see (".5", "1×", "2") and the device's `videoZoomFactor`.
///
/// On a virtual device (triple / dual-wide) `videoZoomFactor` 1 is the ultra-wide lens, so the display
/// multiplier is 0.5 and "1×" is device factor 2.
nonisolated struct ZoomProfile: Hashable, Sendable {
    var minimumDeviceFactor: CGFloat
    var maximumDeviceFactor: CGFloat
    /// displayed = device × multiplier.
    var displayMultiplier: CGFloat

    /// Pinch never goes beyond this, however far the hardware could crop.
    static let maximumDisplayZoom: CGFloat = 10
    static let candidatePresets: [CGFloat] = [0.5, 1, 2]

    static let fixed = ZoomProfile(minimumDeviceFactor: 1, maximumDeviceFactor: 1, displayMultiplier: 1)

    var minimumDisplayZoom: CGFloat { minimumDeviceFactor * displayMultiplier }
    var maximumDisplayZoom: CGFloat { min(maximumDeviceFactor * displayMultiplier, Self.maximumDisplayZoom) }

    /// Buttons for the zoom capsule; empty when there's nothing to choose.
    var presets: [CGFloat] {
        let options = Self.candidatePresets.filter {
            $0 >= minimumDisplayZoom - 0.01 && $0 <= maximumDisplayZoom + 0.01
        }
        return options.count > 1 ? options : []
    }

    func clampedDisplay(_ zoom: CGFloat) -> CGFloat {
        min(max(zoom, minimumDisplayZoom), maximumDisplayZoom)
    }

    func deviceFactor(forDisplay zoom: CGFloat) -> CGFloat {
        guard displayMultiplier > 0 else { return minimumDeviceFactor }
        return min(max(clampedDisplay(zoom) / displayMultiplier, minimumDeviceFactor), maximumDeviceFactor)
    }

    func displayZoom(forDevice factor: CGFloat) -> CGFloat { factor * displayMultiplier }

    /// The preset the capsule highlights for the current zoom: the largest one not above it.
    func activePreset(for zoom: CGFloat) -> CGFloat? {
        presets.last { $0 <= zoom + 0.05 } ?? presets.first
    }

    /// Short label: ".5", "1", "2", or "1.4" while pinching between presets.
    static func label(for zoom: CGFloat) -> String {
        let rounded = (zoom * 10).rounded() / 10
        if rounded >= 1, rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        let text = Double(rounded).formatted(.number.precision(.fractionLength(1)))
        // Camera style: ".5" rather than "0.5", in the locale's decimal separator.
        return rounded < 1 && text.hasPrefix("0") ? String(text.dropFirst()) : text
    }

    /// Display multiplier for devices without `displayVideoZoomFactorMultiplier` (before iOS 18):
    /// a virtual device that starts on an ultra-wide lens switches to wide at its first switch-over factor.
    static func legacyMultiplier(hasUltraWide: Bool, switchOverFactors: [CGFloat]) -> CGFloat {
        guard hasUltraWide, let first = switchOverFactors.first, first > 0 else { return 1 }
        return 1 / first
    }

    /// Zoom that lets a single fixed lens fill the frame with a small code while staying at or beyond its
    /// minimum focus distance (Apple's AVCamBarcode approach). Returns 1 when no zoom is needed.
    ///
    /// - Parameters:
    ///   - fieldOfView: horizontal field of view in degrees.
    ///   - minimumFocusDistance: in millimetres; non-positive when unknown.
    ///   - minimumCodeSize: smallest code to support, in millimetres.
    ///   - fillFraction: how much of the frame width that code should fill.
    static func recommendedZoom(
        fieldOfView: Float,
        minimumFocusDistance: Int,
        minimumCodeSize: Float = 20,
        fillFraction: Float = 0.5625,
        cap: CGFloat = 2
    ) -> CGFloat {
        guard minimumFocusDistance > 0, fieldOfView > 0, fillFraction > 0 else { return 1 }
        let halfAngle = fieldOfView / 2 * .pi / 180
        let subjectDistance = (minimumCodeSize / fillFraction) / tan(halfAngle)
        guard subjectDistance > 0, subjectDistance < Float(minimumFocusDistance) else { return 1 }
        return min(CGFloat(Float(minimumFocusDistance) / subjectDistance), cap)
    }
}
