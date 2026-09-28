import Foundation

/// Everything that makes a created code look the way it does. Stored with History records
/// (`ScanRecord.styleData`) and as reusable "My styles" (`SavedStyle.styleData`).
nonisolated struct CodeStyle: Codable, Hashable, Sendable {
    enum DotShape: String, Codable, CaseIterable, Sendable {
        case square, rounded, dots, diamond, fluid, classy
    }

    enum EyeFrame: String, Codable, CaseIterable, Sendable {
        case square, rounded, circle, leaf
    }

    enum EyePupil: String, Codable, CaseIterable, Sendable {
        case square, rounded, circle, diamond
    }

    enum Background: String, Codable, CaseIterable, Sendable {
        case white, transparent, tinted
    }

    enum Frame: String, Codable, CaseIterable, Sendable {
        case none, card, badge, poster
    }

    enum CaptionWeight: String, Codable, CaseIterable, Sendable {
        case regular, medium, semibold, bold, heavy
    }

    enum PhotoShape: String, Codable, CaseIterable, Sendable {
        case circle, rounded
    }

    enum Logo: Codable, Hashable, Sendable {
        case none
        /// The SF Symbol of whatever the code holds (Wi-Fi glyph for a network, and so on).
        case kindGlyph
        /// Square-cropped, downscaled image data.
        case photo(Data, PhotoShape)
        case initials(String)
    }

    var dots: DotShape = .square
    var eyeFrame: EyeFrame = .square
    var eyePupil: EyePupil = .square
    /// When set, finder eyes use `eyeColor` instead of matching the dots.
    var accentEyes = false
    var eyeColor = RGBAColor(hex: 0x0071A4)

    var foreground = RGBAColor.black
    var usesGradient = false
    var gradientEnd = RGBAColor(hex: 0x0B5A6F)
    var background: Background = .white
    /// Built-in palette this style came from, for highlighting in the picker.
    var paletteID: String? = "mono"

    var correction: CorrectionLevel = .medium
    var logo: Logo = .none

    var frame: Frame = .none
    var caption = ""
    var captionWeight: CaptionWeight = .semibold
    /// Digits under 1-D barcodes.
    var showsText = true

    /// A logo covers modules, so it always gets the strongest error correction.
    var effectiveCorrection: CorrectionLevel { logo == .none ? correction : .high }

    /// Opaque background, or `nil` when transparent.
    var backgroundColor: RGBAColor? {
        switch background {
        case .white: .white
        case .transparent: nil
        case .tinted: foreground.mixed(with: .white, amount: 0.9)
        }
    }

    /// The lightest color any dark module can take; drives the contrast check.
    var lightestInk: RGBAColor {
        var candidates = [foreground]
        if usesGradient { candidates.append(gradientEnd) }
        if accentEyes { candidates.append(eyeColor) }
        return candidates.max { $0.relativeLuminance < $1.relativeLuminance }!
    }

    /// Keeps only the look (shapes, colors, logo, frame), leaving the per-code caption alone.
    func applyingLook(of other: CodeStyle) -> CodeStyle {
        var result = other
        result.caption = caption
        return result
    }

    func encoded() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }

    static func decoded(from data: Data?) -> CodeStyle? {
        data.flatMap { try? JSONDecoder().decode(CodeStyle.self, from: $0) }
    }
}
