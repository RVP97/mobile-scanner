import Foundation

/// A grid of dark (`true`) and light cells, row-major, top row first.
nonisolated struct BitMatrix: Hashable, Sendable {
    let width: Int
    let height: Int
    private(set) var cells: [Bool]

    init(width: Int, height: Int, cells: [Bool]? = nil) {
        precondition(cells == nil || cells!.count == width * height)
        self.width = width
        self.height = height
        self.cells = cells ?? Array(repeating: false, count: width * height)
    }

    subscript(row: Int, column: Int) -> Bool {
        get { cells[row * width + column] }
        set { cells[row * width + column] = newValue }
    }

    /// `false` outside the grid, so neighbour lookups need no bounds checks.
    func isDark(row: Int, column: Int) -> Bool {
        guard row >= 0, column >= 0, row < height, column < width else { return false }
        return self[row, column]
    }
}

/// A one-dimensional symbol: a run of bar (`true`) and space modules plus the digits printed under it.
nonisolated struct LinearBarcode: Hashable, Sendable {
    /// A piece of human-readable text centred over a span of modules. Spans may extend into the
    /// quiet zone (negative start, or past `modules.count`), as EAN/UPC lead digits do.
    struct TextRun: Hashable, Sendable {
        var text: String
        var start: Double
        var end: Double
    }

    var modules: [Bool]
    /// Module indices that extend down into the text band (EAN/UPC guard bars).
    var guardModules: IndexSet = []
    var text: [TextRun] = []
    /// Bar height in modules, before any text.
    var barHeight: Double
    /// Light modules required on each side.
    var quietZone: Double = 10

    init(modules: [Bool], guardModules: IndexSet = [], text: [TextRun] = [], barHeight: Double? = nil, quietZone: Double = 10) {
        self.modules = modules
        self.guardModules = guardModules
        self.text = text
        self.quietZone = quietZone
        self.barHeight = barHeight ?? min(max(Double(modules.count) * 0.3, 36), 90)
    }

    /// Consecutive dark modules merged into `(start, length)` bars, so rendering never shows seams.
    var bars: [(start: Int, length: Int)] {
        var result: [(Int, Int)] = []
        var index = 0
        while index < modules.count {
            if modules[index] {
                let start = index
                while index < modules.count, modules[index] { index += 1 }
                result.append((start, index - start))
            } else {
                index += 1
            }
        }
        return result
    }

    /// A single centred caption spanning the whole symbol.
    static func centeredText(_ text: String, over count: Int) -> [TextRun] {
        [TextRun(text: text, start: 0, end: Double(count))]
    }
}

/// What an encoder produces: something the scene builder can draw.
nonisolated enum CodeGraphic: Hashable, Sendable {
    case matrix(BitMatrix, quietZone: Int)
    case linear(LinearBarcode)
}

/// Builds module runs from narrow/wide element widths, alternating bar and space.
nonisolated struct ModuleWriter {
    private(set) var modules: [Bool] = []

    mutating func append(bar width: Int) { modules += Array(repeating: true, count: width) }
    mutating func append(space width: Int) { modules += Array(repeating: false, count: width) }

    /// Appends a bit pattern string such as `"1011"`.
    mutating func append(pattern: String) {
        for character in pattern { modules.append(character == "1") }
    }

    /// Appends alternating elements starting with a bar; `true` in `wide` means a wide element.
    mutating func append(elements wide: [Bool], narrow: Int = 1, wideWidth: Int = 3, startingWithBar: Bool = true) {
        var isBar = startingWithBar
        for isWide in wide {
            let width = isWide ? wideWidth : narrow
            isBar ? append(bar: width) : append(space: width)
            isBar.toggle()
        }
    }
}
