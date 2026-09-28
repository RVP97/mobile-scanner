import CoreGraphics
import SwiftUI

/// An sRGB color that survives encoding and crosses threads, unlike `Color`.
nonisolated struct RGBAColor: Codable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    static let black = RGBAColor(red: 0, green: 0, blue: 0)
    static let white = RGBAColor(red: 1, green: 1, blue: 1)

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    var cgColor: CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    var hexString: String {
        String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }

    func withAlpha(_ alpha: Double) -> RGBAColor {
        RGBAColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Linear interpolation towards `other`; `amount` 0 keeps self, 1 gives `other`.
    func mixed(with other: RGBAColor, amount: Double) -> RGBAColor {
        RGBAColor(
            red: red + (other.red - red) * amount,
            green: green + (other.green - green) * amount,
            blue: blue + (other.blue - blue) * amount,
            alpha: alpha + (other.alpha - alpha) * amount
        )
    }

    /// This color flattened onto an opaque backdrop.
    func composited(over backdrop: RGBAColor) -> RGBAColor {
        RGBAColor(
            red: red * alpha + backdrop.red * (1 - alpha),
            green: green * alpha + backdrop.green * (1 - alpha),
            blue: blue * alpha + backdrop.blue * (1 - alpha)
        )
    }

    // MARK: WCAG 2 contrast

    /// Relative luminance per WCAG 2.x (sRGB transfer function, Rec. 709 weights).
    var relativeLuminance: Double {
        func linear(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// Contrast ratio between two opaque colors, 1…21.
    static func contrast(_ a: RGBAColor, _ b: RGBAColor) -> Double {
        let la = a.relativeLuminance, lb = b.relativeLuminance
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}

extension RGBAColor {
    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }

    /// Resolves a SwiftUI color (as chosen in a `ColorPicker`) to sRGB components.
    init(_ color: Color) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(
            red: min(max(Double(r), 0), 1),
            green: min(max(Double(g), 0), 1),
            blue: min(max(Double(b), 0), 1),
            alpha: min(max(Double(a), 0), 1)
        )
    }
}
