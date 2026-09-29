import Foundation

/// A code to show full screen: what it says, how it's drawn, and the owner's style if they made it.
struct ShowCodeItem: Identifiable, Hashable {
    let id = UUID()
    var raw: String
    var symbology: Symbology
    var payload: Payload
    var title: String
    /// The studio style of a created code; nil draws it plain.
    var style: CodeStyle?

    var kind: CodeKind { payload.kind }

    init(raw: String, symbology: Symbology, payload: Payload, title: String, style: CodeStyle? = nil) {
        self.raw = raw
        self.symbology = symbology
        self.payload = payload
        self.title = title
        self.style = style
    }

    init(record: ScanRecord) {
        self.init(
            raw: record.raw,
            symbology: record.symbology,
            payload: PayloadParser.parse(record.raw, symbology: record.symbology),
            title: record.historyTitle,
            style: CodeStyle.decoded(from: record.styleData)
        )
    }

    init(result: ScanResult) {
        self.init(raw: result.code.raw, symbology: result.code.symbology, payload: result.payload, title: result.payload.displayTitle)
    }
}
