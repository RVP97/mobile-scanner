import SwiftUI

/// Lens color tokens. Every color adapts to light and dark; the camera surfaces are always dark.
enum Palette {
    /// Brand accent: the lens cyan.
    static let accent = Color(light: 0x0071A4, dark: 0x64D2FF)

    /// Label color to put on top of a filled tint (kind buttons, accent buttons).
    static let onTint = Color(light: 0xFFFFFF, dark: 0x000000)

    static let safe = Color(light: 0x1E7A34, dark: 0x30D158)
    static let caution = Color(light: 0x8A5A00, dark: 0xFFD60A)
    static let danger = Color(light: 0xC4231B, dark: 0xFF453A)

    /// Soft fill behind a kind glyph.
    static func tileFill(_ kind: CodeKind) -> Color { kind.tint.opacity(0.18) }

    static func tint(for kind: CodeKind) -> Color {
        switch kind {
        case .link: Color(light: 0x0071A4, dark: 0x64D2FF)
        case .wifi: Color(light: 0x1E7A34, dark: 0x30D158)
        case .product: Color(light: 0xB25000, dark: 0xFF9F0A)
        case .contact: Color(light: 0x8A2BB9, dark: 0xBF5AF2)
        case .event: Color(light: 0xC4231B, dark: 0xFF6961)
        case .email: Color(light: 0x0A5FCC, dark: 0x409CFF)
        case .sms: Color(light: 0x1E7A34, dark: 0x30DB5B)
        case .phone: Color(light: 0x1E7A34, dark: 0x30D158)
        case .location: Color(light: 0xC4231B, dark: 0xFF6961)
        case .travel: Color(light: 0xC2185B, dark: 0xFF375F)
        case .crypto: Color(light: 0xA15C00, dark: 0xFFB340)
        case .shipment: Color(light: 0x7A5C3A, dark: 0xC4A07A)
        case .text: Color(light: 0x48484A, dark: 0xD1D1D6)
        }
    }
}

extension Color {
    /// A dynamic color from two sRGB hex values. `nonisolated` because UIKit resolves the
    /// provider on SwiftUI's render thread, not the main actor.
    nonisolated init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { @Sendable traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    nonisolated convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
