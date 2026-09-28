import CoreGraphics

/// Everything needed to lay out a finished code. Main-actor-only pieces (SF Symbol rendering,
/// localized strings) are resolved up front so building and rendering can run anywhere.
nonisolated struct SceneInput: @unchecked Sendable {
    var graphic: CodeGraphic
    var geometry: ModuleGeometry?
    var style: CodeStyle
    /// Kind glyph or photo for the centre of a QR code.
    var logoImage: CGImage?
    /// Small line under the code on the poster frame.
    var posterHint: String = ""
}

/// Lays out code, logo, frame and caption as an `ArtworkScene`. The code block is always
/// `codeWidth` units wide; frames are proportioned from it.
nonisolated enum SceneBuilder {
    static let codeWidth: CGFloat = 1000

    static func scene(for input: SceneInput) -> ArtworkScene {
        let style = input.style
        var code = codeBlock(input)
        let caption = style.frame == .none ? "" : style.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = codeWidth, cw = code.size.width, ch = code.size.height
        let background = style.backgroundColor
        let ink = style.foreground
        var items: [ArtworkScene.Item] = []
        let size: CGSize
        let codeOrigin: CGPoint

        switch style.frame {
        case .none:
            size = code.size
            codeOrigin = .zero
            if let background { items.append(.fill(CGPath(rect: CGRect(origin: .zero, size: size), transform: nil), .solid(background))) }

        case .card:
            let pad = 0.04 * c, band = caption.isEmpty ? 0 : 0.12 * c
            size = CGSize(width: cw + 2 * pad, height: ch + 2 * pad + band)
            codeOrigin = CGPoint(x: pad, y: pad)
            let card = CGPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1), cornerWidth: 0.07 * c, cornerHeight: 0.07 * c, transform: nil)
            if let background { items.append(.fill(card, .solid(background))) }
            items.append(.stroke(card, ink.withAlpha(0.16), width: 0.004 * c))
            if !caption.isEmpty {
                items.append(.text(.init(
                    string: caption, rect: CGRect(x: pad * 2, y: pad + ch - 0.015 * c, width: cw - 2 * pad, height: band),
                    fontSize: 0.068 * c, weight: style.captionWeight, color: ink
                ).fitted()))
            }

        case .badge:
            let border = 0.035 * c, innerPad = 0.03 * c, band = caption.isEmpty ? border : 0.15 * c
            let inner = CGRect(x: border, y: border, width: cw + 2 * innerPad, height: ch + 2 * innerPad)
            size = CGSize(width: inner.width + 2 * border, height: border + inner.height + band)
            codeOrigin = CGPoint(x: inner.minX + innerPad, y: inner.minY + innerPad)
            let outerPath = CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: 0.08 * c, cornerHeight: 0.08 * c, transform: nil)
            let innerPath = CGPath(roundedRect: inner, cornerWidth: 0.05 * c, cornerHeight: 0.05 * c, transform: nil)
            let ring = CGMutablePath()
            ring.addPath(outerPath)
            ring.addPath(innerPath)
            items.append(.fill(ring, .solid(ink), evenOdd: true))
            if let background { items.append(.fill(innerPath, .solid(background))) }
            if !caption.isEmpty {
                items.append(.text(.init(
                    string: caption, rect: CGRect(x: border * 2, y: inner.maxY, width: size.width - 4 * border, height: band),
                    fontSize: 0.075 * c, weight: style.captionWeight, color: background ?? .white
                ).fitted()))
            }

        case .poster:
            let pad = 0.08 * c, titleBand = caption.isEmpty ? 0 : 0.2 * c, hintBand = 0.12 * c
            size = CGSize(width: cw + 2 * pad, height: pad + titleBand + ch + hintBand + pad * 0.5)
            codeOrigin = CGPoint(x: pad, y: pad + titleBand)
            let sheet = CGPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1), cornerWidth: 0.03 * c, cornerHeight: 0.03 * c, transform: nil)
            if let background { items.append(.fill(sheet, .solid(background))) }
            items.append(.stroke(sheet, ink.withAlpha(0.16), width: 0.004 * c))
            if !caption.isEmpty {
                items.append(.text(.init(
                    string: caption, rect: CGRect(x: pad, y: pad, width: cw, height: titleBand * 0.75),
                    fontSize: 0.095 * c, weight: style.captionWeight, color: ink
                ).fitted()))
            }
            if !input.posterHint.isEmpty {
                items.append(.text(.init(
                    string: input.posterHint, rect: CGRect(x: pad, y: pad + titleBand + ch, width: cw, height: hintBand * 0.7),
                    fontSize: 0.045 * c, weight: .regular, color: ink.withAlpha(0.62)
                ).fitted()))
            }
        }

        code.offset(by: codeOrigin)
        items += code.items
        return ArtworkScene(size: size, items: items, codeRect: CGRect(origin: codeOrigin, size: code.size))
    }

    // MARK: Code block

    private struct Block {
        var size: CGSize
        var items: [ArtworkScene.Item]

        mutating func offset(by point: CGPoint) {
            guard point != .zero else { return }
            var transform = CGAffineTransform(translationX: point.x, y: point.y)
            items = items.map { item in
                switch item {
                case .fill(let path, let paint, let evenOdd):
                    return .fill(path.copy(using: &transform) ?? path, paint.offset(by: point), evenOdd: evenOdd)
                case .stroke(let path, let color, let width):
                    return .stroke(path.copy(using: &transform) ?? path, color, width: width)
                case .text(var text):
                    text.rect = text.rect.offsetBy(dx: point.x, dy: point.y)
                    return .text(text)
                case .image(let image, let rect, let clip):
                    return .image(image, rect.offsetBy(dx: point.x, dy: point.y), clip: clip.flatMap { $0.copy(using: &transform) })
                }
            }
        }
    }

    private static func codePaint(_ style: CodeStyle, size: CGSize) -> ArtworkScene.Paint {
        style.usesGradient
            ? .linear(style.foreground, style.gradientEnd, start: .zero, end: CGPoint(x: size.width, y: size.height))
            : .solid(style.foreground)
    }

    private static func codeBlock(_ input: SceneInput) -> Block {
        switch input.graphic {
        case .matrix(let matrix, let quietZone):
            matrixBlock(matrix, quietZone: quietZone, input: input)
        case .linear(let barcode):
            linearBlock(barcode, style: input.style)
        }
    }

    private static func matrixBlock(_ matrix: BitMatrix, quietZone: Int, input: SceneInput) -> Block {
        let style = input.style
        let geometry = input.geometry ?? ModuleGeometry.plain(matrix)
        let module = codeWidth / CGFloat(matrix.width + 2 * quietZone)
        let size = CGSize(width: codeWidth, height: CGFloat(matrix.height + 2 * quietZone) * module)
        var transform = CGAffineTransform(translationX: CGFloat(quietZone) * module, y: CGFloat(quietZone) * module)
            .scaledBy(x: module, y: module)
        let paint = codePaint(style, size: size)
        let eyePaint: ArtworkScene.Paint = style.accentEyes ? .solid(style.eyeColor) : paint

        var items: [ArtworkScene.Item] = []
        if let dots = geometry.dots.copy(using: &transform) { items.append(.fill(dots, paint)) }
        if !geometry.eyeFrames.isEmpty, let frames = geometry.eyeFrames.copy(using: &transform) {
            items.append(.fill(frames, eyePaint, evenOdd: true))
        }
        if !geometry.pupils.isEmpty, let pupils = geometry.pupils.copy(using: &transform) {
            items.append(.fill(pupils, eyePaint))
        }
        if let box = geometry.logoBox?.applying(transform) {
            items += logoItems(style: style, image: input.logoImage, box: box)
        }
        return Block(size: size, items: items)
    }

    private static func logoItems(style: CodeStyle, image: CGImage?, box: CGRect) -> [ArtworkScene.Item] {
        switch style.logo {
        case .none:
            return []
        case .kindGlyph:
            guard let image else { return [] }
            let area = box.insetBy(dx: box.width * 0.1, dy: box.height * 0.1)
            let aspect = CGFloat(image.width) / CGFloat(max(image.height, 1))
            let fitted = aspect >= 1
                ? CGRect(x: area.minX, y: area.midY - area.width / aspect / 2, width: area.width, height: area.width / aspect)
                : CGRect(x: area.midX - area.height * aspect / 2, y: area.minY, width: area.height * aspect, height: area.height)
            return [.image(image, fitted, clip: nil)]
        case .photo(_, let shape):
            guard let image else { return [] }
            let area = box.insetBy(dx: box.width * 0.04, dy: box.height * 0.04)
            let clip = shape == .circle
                ? CGPath(ellipseIn: area, transform: nil)
                : CGPath(roundedRect: area, cornerWidth: area.width * 0.22, cornerHeight: area.width * 0.22, transform: nil)
            return [.image(image, area, clip: clip)]
        case .initials(let initials):
            let area = box.insetBy(dx: box.width * 0.04, dy: box.height * 0.04)
            let text = String(initials.trimmingCharacters(in: .whitespaces).uppercased().prefix(3))
            return [
                .fill(CGPath(ellipseIn: area, transform: nil), .solid(style.accentEyes ? style.eyeColor : style.foreground)),
                .text(.init(
                    string: text, rect: area.insetBy(dx: area.width * 0.14, dy: 0),
                    fontSize: area.height * 0.42, weight: .bold, color: style.backgroundColor ?? .white
                ).fitted()),
            ]
        }
    }

    private static func linearBlock(_ barcode: LinearBarcode, style: CodeStyle) -> Block {
        let totalModules = CGFloat(barcode.modules.count) + 2 * barcode.quietZone
        let module = codeWidth / totalModules
        let isRetail = !barcode.guardModules.isEmpty
        let textSize: CGFloat = isRetail ? 10 : max(10, totalModules * 0.06)
        let padding: CGFloat = 4
        let showsText = style.showsText && !barcode.text.isEmpty
        let barTop = padding * module
        let barHeight = CGFloat(barcode.barHeight) * module
        let guardExtra = showsText && isRetail ? textSize * 0.55 * module : 0
        let height = (padding * 2 + CGFloat(barcode.barHeight) + (showsText ? textSize + 1.5 : 0)) * module
        let size = CGSize(width: codeWidth, height: height)
        let left = CGFloat(barcode.quietZone) * module

        // Split bars wherever guard membership changes so guard bars can run taller.
        let bars = CGMutablePath()
        var index = 0
        while index < barcode.modules.count {
            guard barcode.modules[index] else {
                index += 1
                continue
            }
            let start = index, isGuard = barcode.guardModules.contains(index)
            while index < barcode.modules.count, barcode.modules[index], barcode.guardModules.contains(index) == isGuard { index += 1 }
            bars.addRect(CGRect(
                x: left + CGFloat(start) * module, y: barTop,
                width: CGFloat(index - start) * module, height: barHeight + (isGuard ? guardExtra : 0)
            ))
        }

        var items: [ArtworkScene.Item] = [.fill(bars, codePaint(style, size: size))]
        if showsText {
            let textTop = barTop + barHeight + 1.5 * module
            for run in barcode.text {
                items.append(.text(.init(
                    string: run.text,
                    rect: CGRect(x: left + run.start * module, y: textTop, width: (run.end - run.start) * module, height: textSize * module),
                    fontSize: textSize * module, weight: .medium, monospaced: true, color: style.foreground
                ).fitted()))
            }
        }
        return Block(size: size, items: items)
    }
}

private extension ArtworkScene.Paint {
    nonisolated func offset(by point: CGPoint) -> ArtworkScene.Paint {
        switch self {
        case .solid: self
        case .linear(let a, let b, let start, let end):
            .linear(a, b, start: CGPoint(x: start.x + point.x, y: start.y + point.y), end: CGPoint(x: end.x + point.x, y: end.y + point.y))
        }
    }
}
