import CoreGraphics
import CoreText
import UIKit

/// A resolution-independent drawing of a finished code (code, logo, frame, caption), described as
/// a flat list of primitives so the same scene feeds the live preview, PNG, PDF, print and SVG.
/// Coordinates are top-left origin, in scene units.
nonisolated struct ArtworkScene: @unchecked Sendable {
    enum Paint {
        case solid(RGBAColor)
        case linear(RGBAColor, RGBAColor, start: CGPoint, end: CGPoint)
    }

    struct Text {
        var string: String
        /// Box the text is centred in (horizontally and on its cap height vertically).
        var rect: CGRect
        var fontSize: CGFloat
        var weight: CodeStyle.CaptionWeight
        var monospaced = false
        var color: RGBAColor
    }

    enum Item {
        case fill(CGPath, Paint, evenOdd: Bool = false)
        case stroke(CGPath, RGBAColor, width: CGFloat)
        case text(Text)
        case image(CGImage, CGRect, clip: CGPath?)
        /// Paints `rect` through a grayscale mask (white shows paint), so glyphs take gradients too.
        case mask(CGImage, CGRect, Paint)
    }

    var size: CGSize
    var items: [Item] = []
}

extension ArtworkScene.Text {
    nonisolated var font: CTFont {
        let weight: UIFont.Weight = switch self.weight {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        }
        let font = monospaced
            ? UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: weight)
            : UIFont.systemFont(ofSize: fontSize, weight: weight)
        return font as CTFont
    }

    nonisolated func line() -> CTLine {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
        ]
        return CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
    }

    /// Width the string needs at `fontSize`.
    nonisolated var measuredWidth: CGFloat {
        CGFloat(CTLineGetTypographicBounds(line(), nil, nil, nil))
    }

    /// Shrinks the font until the string fits `rect.width` (down to 55%), then gives up and lets it clip.
    nonisolated func fitted() -> ArtworkScene.Text {
        var copy = self
        let width = measuredWidth
        if width > rect.width, width > 0 {
            copy.fontSize = max(fontSize * rect.width / width, fontSize * 0.55)
        }
        return copy
    }

    /// Baseline origin that centres the cap height in `rect`.
    nonisolated var baseline: CGPoint {
        let capHeight = CTFontGetCapHeight(font)
        let width = min(measuredWidth, rect.width)
        return CGPoint(x: rect.midX - width / 2, y: rect.midY + capHeight / 2)
    }
}
