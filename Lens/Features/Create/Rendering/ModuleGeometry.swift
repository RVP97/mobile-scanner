import CoreGraphics

/// Vector outlines of a matrix code in module units (one module = 1×1, quiet zone excluded).
/// QR codes get styled dots, finder eyes and a cleared logo area; other matrices get plain squares.
nonisolated struct ModuleGeometry: @unchecked Sendable {
    /// Data modules.
    var dots: CGPath
    /// Finder-eye rings; fill with the even-odd rule.
    var eyeFrames: CGPath
    var pupils: CGPath
    /// Square area left clear for a logo, in module units.
    var logoBox: CGRect?

    /// Logo edge as a share of the symbol edge. Small enough to stay well inside level-H recovery.
    static let logoFraction = 0.22

    static func plain(_ matrix: BitMatrix) -> ModuleGeometry {
        let path = CGMutablePath()
        addRuns(of: matrix, to: path) { _, _ in true }
        return ModuleGeometry(dots: path, eyeFrames: CGMutablePath(), pupils: CGMutablePath(), logoBox: nil)
    }

    static func qr(_ matrix: BitMatrix, style: CodeStyle) -> ModuleGeometry {
        let n = matrix.width
        let logoBox: CGRect? = style.logo == .none ? nil : {
            var side = (Double(n) * logoFraction).rounded()
            if Int(side).isMultiple(of: 2) { side += 1 }  // keep it on the module grid
            let origin = (Double(n) - side) / 2
            return CGRect(x: origin, y: origin, width: side, height: side)
        }()
        let clearBox = logoBox?.insetBy(dx: -0.5, dy: -0.5)

        func isEye(_ row: Int, _ column: Int) -> Bool {
            (row < 7 && column < 7) || (row < 7 && column >= n - 7) || (row >= n - 7 && column < 7)
        }
        func isDot(_ row: Int, _ column: Int) -> Bool {
            guard matrix.isDark(row: row, column: column), !isEye(row, column) else { return false }
            if let clearBox, clearBox.contains(CGPoint(x: Double(column) + 0.5, y: Double(row) + 0.5)) { return false }
            return true
        }

        let dots = CGMutablePath()
        if style.dots == .square {
            addRuns(of: matrix, to: dots, where: isDot)
        } else {
            for row in 0..<n {
                for column in 0..<n where isDot(row, column) {
                    addDot(style.dots, row: row, column: column, to: dots, isDot: isDot)
                }
            }
        }

        let frames = CGMutablePath(), pupils = CGMutablePath()
        let corners = [(0, 0, Corner.topLeft), (0, n - 7, Corner.topRight), (n - 7, 0, Corner.bottomLeft)]
        for (row, column, corner) in corners {
            let origin = CGPoint(x: column, y: row)
            addEyeFrame(style.eyeFrame, at: origin, corner: corner, to: frames)
            addPupil(style.eyePupil, in: CGRect(x: origin.x + 2, y: origin.y + 2, width: 3, height: 3), to: pupils)
        }
        return ModuleGeometry(dots: dots, eyeFrames: frames, pupils: pupils, logoBox: logoBox)
    }

    // MARK: Dots

    /// Horizontal runs merged into single rectangles so square modules never show hairline seams.
    private static func addRuns(of matrix: BitMatrix, to path: CGMutablePath, where include: (Int, Int) -> Bool) {
        for row in 0..<matrix.height {
            var column = 0
            while column < matrix.width {
                guard matrix[row, column], include(row, column) else {
                    column += 1
                    continue
                }
                let start = column
                while column < matrix.width, matrix[row, column], include(row, column) { column += 1 }
                path.addRect(CGRect(x: start, y: row, width: column - start, height: 1))
            }
        }
    }

    private static func addDot(_ shape: CodeStyle.DotShape, row: Int, column: Int, to path: CGMutablePath, isDot: (Int, Int) -> Bool) {
        let cell = CGRect(x: column, y: row, width: 1, height: 1)
        switch shape {
        case .square:
            path.addRect(cell)
        case .rounded:
            path.addRoundedRect(in: cell.insetBy(dx: 0.06, dy: 0.06), cornerWidth: 0.28, cornerHeight: 0.28)
        case .dots:
            path.addEllipse(in: cell.insetBy(dx: 0.06, dy: 0.06))
        case .diamond:
            let inset = cell.insetBy(dx: 0.02, dy: 0.02)
            path.addLines(between: [
                CGPoint(x: inset.midX, y: inset.minY), CGPoint(x: inset.maxX, y: inset.midY),
                CGPoint(x: inset.midX, y: inset.maxY), CGPoint(x: inset.minX, y: inset.midY),
            ])
            path.closeSubpath()
        case .fluid, .classy:
            let up = isDot(row - 1, column), down = isDot(row + 1, column)
            let left = isDot(row, column - 1), right = isDot(row, column + 1)
            let r = 0.5
            var radii = CornerRadii(
                topLeft: !up && !left ? r : 0,
                topRight: !up && !right ? r : 0,
                bottomRight: !down && !right ? r : 0,
                bottomLeft: !down && !left ? r : 0
            )
            if shape == .classy {
                radii.topRight = 0
                radii.bottomLeft = 0
            }
            path.addRect(cell, radii: radii)
        }
    }

    // MARK: Eyes

    private enum Corner { case topLeft, topRight, bottomLeft }

    private static func addEyeFrame(_ shape: CodeStyle.EyeFrame, at origin: CGPoint, corner: Corner, to path: CGMutablePath) {
        let outer = CGRect(origin: origin, size: CGSize(width: 7, height: 7))
        let inner = outer.insetBy(dx: 1, dy: 1)
        switch shape {
        case .square:
            path.addRect(outer)
            path.addRect(inner)
        case .rounded:
            path.addRoundedRect(in: outer, cornerWidth: 2.2, cornerHeight: 2.2)
            path.addRoundedRect(in: inner, cornerWidth: 1.3, cornerHeight: 1.3)
        case .circle:
            path.addEllipse(in: outer)
            path.addEllipse(in: inner)
        case .leaf:
            path.addRect(outer, radii: leafRadii(big: 3.2, small: 0.6, corner: corner))
            path.addRect(inner, radii: leafRadii(big: 2.2, small: 0.2, corner: corner))
        }
    }

    /// Rounds the outward corner and the one facing the code's centre.
    private static func leafRadii(big: CGFloat, small: CGFloat, corner: Corner) -> CornerRadii {
        switch corner {
        case .topLeft: CornerRadii(topLeft: big, topRight: small, bottomRight: big, bottomLeft: small)
        case .topRight: CornerRadii(topLeft: small, topRight: big, bottomRight: small, bottomLeft: big)
        case .bottomLeft: CornerRadii(topLeft: small, topRight: big, bottomRight: small, bottomLeft: big)
        }
    }

    private static func addPupil(_ shape: CodeStyle.EyePupil, in rect: CGRect, to path: CGMutablePath) {
        switch shape {
        case .square:
            path.addRect(rect)
        case .rounded:
            path.addRoundedRect(in: rect, cornerWidth: 0.9, cornerHeight: 0.9)
        case .circle:
            path.addEllipse(in: rect)
        case .diamond:
            let grown = rect.insetBy(dx: -0.35, dy: -0.35)
            path.addLines(between: [
                CGPoint(x: grown.midX, y: grown.minY), CGPoint(x: grown.maxX, y: grown.midY),
                CGPoint(x: grown.midX, y: grown.maxY), CGPoint(x: grown.minX, y: grown.midY),
            ])
            path.closeSubpath()
        }
    }
}

nonisolated struct CornerRadii {
    var topLeft: CGFloat
    var topRight: CGFloat
    var bottomRight: CGFloat
    var bottomLeft: CGFloat
}

extension CGMutablePath {
    /// A rectangle with an independent radius per corner (top-left-origin coordinates).
    nonisolated func addRect(_ rect: CGRect, radii: CornerRadii) {
        let limit = min(rect.width, rect.height) / 2
        let tl = min(radii.topLeft, limit), tr = min(radii.topRight, limit)
        let br = min(radii.bottomRight, limit), bl = min(radii.bottomLeft, limit)
        move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        if tr > 0 { addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + tr), radius: tr) }
        addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        if br > 0 { addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - br, y: rect.maxY), radius: br) }
        addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        if bl > 0 { addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - bl), radius: bl) }
        addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        if tl > 0 { addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + tl, y: rect.minY), radius: tl) }
        closeSubpath()
    }
}
