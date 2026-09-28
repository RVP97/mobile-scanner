import Foundation

/// One-tap corrections the scannability meter offers.
enum StudioFix {
    case darkenInk, removeLogo, simplifyShapes

    var title: LocalizedStringResource {
        switch self {
        case .darkenInk: "Darken"
        case .removeLogo: "Remove Logo"
        case .simplifyShapes: "Use Squares"
        }
    }
}

extension StudioModel {
    func apply(_ fix: StudioFix) {
        switch fix {
        case .darkenInk: style = Self.darkened(style)
        case .removeLogo: style.logo = .none
        case .simplifyShapes:
            style.dots = .square
            style.eyeFrame = .square
            style.eyePupil = .square
        }
    }

    /// Mixes every ink toward black, keeping its hue, until contrast is comfortable.
    static func darkened(_ style: CodeStyle) -> CodeStyle {
        var result = style
        if result.background == .tinted { result.background = .white }
        var attempts = 0
        while attempts < 24 {
            let contrast = ScannabilityChecker.contrast(for: result)
            if contrast.ratio >= ScannabilityChecker.comfortableContrast, !contrast.inverted { break }
            result.foreground = result.foreground.mixed(with: .black, amount: 0.15)
            result.gradientEnd = result.gradientEnd.mixed(with: .black, amount: 0.15)
            result.eyeColor = result.eyeColor.mixed(with: .black, amount: 0.15)
            result.paletteID = nil
            attempts += 1
        }
        return result
    }
}
