import Foundation

/// A named foreground/gradient pair offered in the Color tool.
struct CodePalette: Identifiable {
    let id: String
    let name: LocalizedStringResource
    let start: RGBAColor
    let end: RGBAColor

    static let all: [CodePalette] = [
        CodePalette(id: "mono", name: "Mono", start: .black, end: RGBAColor(hex: 0x3A3A3C)),
        CodePalette(id: "lagoon", name: "Lagoon", start: RGBAColor(hex: 0x062B45), end: RGBAColor(hex: 0x0B5A6F)),
        CodePalette(id: "tangerine", name: "Tangerine", start: RGBAColor(hex: 0xE8890C), end: RGBAColor(hex: 0xFFB340)),
        CodePalette(id: "forest", name: "Forest", start: RGBAColor(hex: 0x0F3D2A), end: RGBAColor(hex: 0x1A6440)),
        CodePalette(id: "berry", name: "Berry", start: RGBAColor(hex: 0x5A1340), end: RGBAColor(hex: 0x8C1C5A)),
    ]

    static func named(_ id: String?) -> CodePalette? { all.first { $0.id == id } }
}

/// Built-in looks shown before the person's own saved styles.
struct StylePreset: Identifiable {
    let id: String
    let name: LocalizedStringResource
    let style: CodeStyle

    static let all: [StylePreset] = [
        StylePreset(id: "classic", name: "Classic", style: CodeStyle()),
        StylePreset(id: "soft", name: "Soft", style: {
            var style = CodeStyle()
            style.dots = .rounded
            style.eyeFrame = .rounded
            style.eyePupil = .rounded
            style.foreground = RGBAColor(hex: 0x1C1C1E)
            style.paletteID = nil
            return style
        }()),
        StylePreset(id: "lagoon", name: "Lagoon", style: {
            var style = CodeStyle()
            style.dots = .dots
            style.eyeFrame = .circle
            style.eyePupil = .circle
            style.apply(palette: CodePalette.named("lagoon")!)
            style.usesGradient = true
            return style
        }()),
        StylePreset(id: "forest", name: "Forest", style: {
            var style = CodeStyle()
            style.dots = .fluid
            style.eyeFrame = .leaf
            style.eyePupil = .rounded
            style.apply(palette: CodePalette.named("forest")!)
            style.background = .tinted
            return style
        }()),
        StylePreset(id: "berry", name: "Berry", style: {
            var style = CodeStyle()
            style.dots = .classy
            style.eyeFrame = .rounded
            style.eyePupil = .diamond
            style.apply(palette: CodePalette.named("berry")!)
            style.usesGradient = true
            return style
        }()),
        StylePreset(id: "ink", name: "Ink", style: {
            var style = CodeStyle()
            style.dots = .diamond
            style.eyeFrame = .square
            style.eyePupil = .diamond
            style.foreground = RGBAColor(hex: 0x1C1C1E)
            style.accentEyes = true
            style.eyeColor = RGBAColor(hex: 0x0071A4)
            style.paletteID = nil
            return style
        }()),
    ]
}

extension CodeStyle {
    mutating func apply(palette: CodePalette) {
        foreground = palette.start
        gradientEnd = palette.end
        paletteID = palette.id
    }
}

// MARK: Display names

extension CodeStyle.DotShape {
    var title: LocalizedStringResource {
        switch self {
        case .square: "Square"
        case .rounded: "Rounded"
        case .dots: "Dots"
        case .diamond: "Diamond"
        case .fluid: "Fluid"
        case .classy: "Classy"
        }
    }
}

extension CodeStyle.EyeFrame {
    var title: LocalizedStringResource {
        switch self {
        case .square: "Square"
        case .rounded: "Rounded"
        case .circle: "Circle"
        case .leaf: "Leaf"
        }
    }
}

extension CodeStyle.EyePupil {
    var title: LocalizedStringResource {
        switch self {
        case .square: "Square"
        case .rounded: "Rounded"
        case .circle: "Circle"
        case .diamond: "Diamond"
        }
    }
}

extension CodeStyle.Background {
    var title: LocalizedStringResource {
        switch self {
        case .white: "White"
        case .transparent: "Transparent"
        case .tinted: "Tinted"
        }
    }
}

extension CodeStyle.Frame {
    var title: LocalizedStringResource {
        switch self {
        case .none: "None"
        case .card: "Card"
        case .badge: "Badge"
        case .poster: "Poster"
        }
    }
}

extension CodeStyle.CaptionWeight {
    var title: LocalizedStringResource {
        switch self {
        case .regular: "Regular"
        case .medium: "Medium"
        case .semibold: "Semibold"
        case .bold: "Bold"
        case .heavy: "Heavy"
        }
    }
}
